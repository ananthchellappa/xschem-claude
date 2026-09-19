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
                 "headless/test_ase_meas_1443" \
                 "headless/test_ase_sp_1452" \
                 "headless/test_ase_converge_1459" \
                 "headless/test_ase_conv_gui_1460" \
                 "headless/test_ase_campaign_1462" \
                 "headless/test_ase_campaign_gui_1464" \
                 "headless/test_ase_events_1465" \
                 "headless/test_ase_trnoise_1466" \
                 "headless/test_ase_trnoise_gui_1467" \
                 "headless/test_ase_variant_1470" \
                 "headless/test_ase_simwin_variant_1471" \
                 "headless/test_regression_concurrency_1476" \
                 "headless/test_issue_stamp" \
                 "headless/test_home_isolation" \
                 "headless/test_home_isolation_sh"]
# ⚠ `test_regression_concurrency_1476` IS THE SUITE FOR THIS DRIVER'S OWN
# CONCURRENCY DEFECT, and the paragraph below about wall-clock cost is answered
# up front: measured 2026-09-17 on this tree, **8.5-8.6 s** for 20 checks (8.53,
# 8.63, 8.63 over three runs) -- 2.1% of T1's ~410 s. The batch plan circulated
# 7.4 s for it; that did not reproduce here, and the cost belongs to whoever runs
# T1 next, so take it from a measurement rather than from a paragraph -- this
# file's own comments above have been wrong that way twice.
# It is not free because four of its rows are BEHAVIOURAL: it runs
# a staggered pair of 1500-job miniature cases and a staggered pair of copies of
# THIS FILE, and a race that is not provoked is a row that proves nothing.
#
# ⚠ IT RUNS TWO REGRESSION DRIVERS WHILE T1 IS RUNNING, AND THAT IS SAFE BY
# CONSTRUCTION, NOT BY LUCK. Both copies are driven with their cwd inside the
# suite's own per-pid scratch, with the case lists neutered to /bin/sh stand-ins,
# so their verdict file and their verdict LOCK are `<scratch>/results.log` and
# never this run's. A row that provoked the collision in `tests/` would corrupt
# the very T1 executing it -- which is face 4 doing exactly what it does.
#
# ⚠ AND IT WAS DELIBERATELY UNREGISTERED UNTIL THE FIX LANDED. While the defect
# was open the suite was RED BY DESIGN, and `full_audit.sh:393` picked it up
# anyway through its `ls "$HERE"/test_*.tcl` glob -- so every audit taken in that
# window showed two reds that were the point. A standing red is a defect, not
# furniture: it is registered here now that both of its rows are green.
# ⚠ ISSUE 1471 (Stage 16 task 2 -- the Simulators-window line and the release
# note) IS IN BOTH LISTS. Headless it is pure Tcl and starts nothing: the two
# schema procs the window paints from, the release note held to its rules, and
# the .state round trip. On the display arm (`dcases`) its WG rows open Setup >
# Simulators… through the real menu, and WG7 presses Detect on apt 45.2 and on
# the fork -- the ordinary capability probe, which crashes neither. Every other
# row requires the counted probe door and the stand-ins' MARK file to stay at 0.
# ⚠ ISSUE 1470 (Stage 16 task 1, "the ngspice you actually have") IS HEADLESS
# ONLY, AND ITS SECTIONS M21 AND EX START REAL SIMULATORS: the fork once for the
# `casemodewrite` header, and the ordinary capability probe once per binary
# present (apt 45.2, the fork, stock 47). ⚠ NONE OF THE LINTER'S ROWS STARTS ONE:
# patterns 1-3 abort apt 45.2, and this batch never crashes the user's simulator,
# so section LN drives the linter over strings. It maps no window -- the
# Simulators-window row is task 2's -- and ends with an explicit `exit`.
# ⚠ ISSUE 1465 (Stage 12, event-driven results) IS HEADLESS ONLY, AND ITS SECTION
# EE STARTS BOTH REAL SIMULATORS. Nothing in it maps a window: the digital pane
# it fills is the existing viewer's, reached through `ase::attach_dbs`, and the
# pixels are a `look` debt rather than a row. It ends with an explicit `exit` for
# receipt 39's C13 reason -- a run door is driven, so rc 10 would otherwise be one
# netlist away.
# ⚠ ISSUE 1466 (Stage 13 task 1, transient noise -- the DECK half) IS HEADLESS
# ONLY, AND ITS SECTION EE STARTS BOTH REAL SIMULATORS, twice each plus a
# `notrnoise` run, and reads every results file back with a SECOND ngspice
# process. It maps no window: task 1 draws nothing by construction, and the Tran
# form's section is task 2's. No row pins a drawn number or a point count -- white
# noise differs every run and the two binaries disagree about point counts --
# so it asserts presence, absence, equality between two seeded runs and an
# order-of-magnitude window.
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
# ⚠ `test_ase_sp_1452` IS NOT HERE EITHER, AND THE MEASUREMENT SAYS SO.
# Measured 2026-09-13 on both arms from the `RESULT:` line: **41 checks headless
# and 41 on the dev display, the same rows** (`diff` of the two ok-lists is
# empty), 0.10 s against 0.30 s. Stage 9's DECK half creates no widget at all --
# the Ports table, the S-parameter surface, the matrix picker and Smith/polar
# are the GUI half. The day that lands it earns a line here and its counts will
# say so.
# ⚠ AND IT IS THE ONE SUITE IN THIS LIST THAT REALLY STARTS A SIMULATOR, TWICE.
# Its section SE renders the deck ASE-L writes, runs it on apt 45.2 AND on the
# fork, and reads `S_1_1` back out of the results file -- issue 1449's lesson
# that two halves of a feature tested in different suites never meet. A binary
# that is not there SKIPS with its path printed, so the log can never confuse
# "not tested" with "tested and fine"; `$ASE_SP_NGSPICE` (colon-separated)
# overrides the search.
# ⚠ `test_ase_converge_1459` IS NOT HERE EITHER, AND THE MEASUREMENT SAYS SO.
# Measured 2026-09-13 on both arms from the `RESULT:` line: **76 checks headless
# and 76 on the dev display, the same rows** (`diff` of the two ok-lists is
# empty). Stage 10 task 1 is the DECK half -- the `CKTncDump` and ladder
# parsers, the `optran` speller, the operating-point save/restore and the
# run-health line -- and it creates no widget at all: the ladder pane, the
# remedy assistant, the canvas highlight and the health strip are Stage 10
# task 2. ⚠ THAT TASK HAS NOW LANDED as `test_ase_conv_gui_1460`, which IS in
# `dcases` below; 1459 itself is still headless-only and still 76/76, because
# nothing it ships draws a pixel.
# ⚠ AND IT IS THE SECOND SUITE IN `hcases` THAT REALLY STARTS A SIMULATOR,
# ON BOTH BINARIES. Its section EE renders the deck ASE-L writes, runs it on apt
# 45.2 AND on the fork, reads the ladder and the starred `Last Node Voltages`
# table back through ASE-L's own parsers, and asks the SURPLUS question -- is
# there a ladder line in that log this parser has never heard of. A binary that
# is not there SKIPS with its path printed; `$ASE_CONV_NGSPICE` (colon-separated)
# overrides the search.
# ⚠ `test_ase_conv_gui_1460` IS IN **BOTH** LISTS, AND THAT IS THE WHOLE POINT
# OF IT. Stage 10 task 2 is the SURFACE -- the ladder pane, the remedy assistant
# with its deck diff, the canvas highlight and the run-health strip -- so its
# widget legs exist only under X and self-skip without one. Measured 2026-09-13
# from the `RESULT:` line: **44 checks headless, 103 on the dev display**. The
# headless arm is not redundant: sections CP NC HL DF RM OP are pure Tcl and are
# where the readers are falsified, and section EE starts a real simulator on both
# binaries on BOTH arms -- it is the row that proves the transient rung's
# checkbox really means OFF, by rendering ASE-L's own deck with the box ticked
# and cleared and running both (rc 0 and `v(1) = 1.413677e-02` against rc 1 and
# `The operating point could not be simulated successfully`, one argument apart,
# identical on apt 45.2 and on the fork).
#
# ⚠ `test_ase_campaign_1462` IS HEADLESS-ONLY, AND THE MEASUREMENT SAYS SO.
# Measured 2026-09-13 on both arms from the `RESULT:` line: **133 checks
# headless and 133 on the dev display, the same rows** (`diff` of the two
# ok-lists is empty). Stage 11 task 1 is the campaign RUNNER and the SAMPLER --
# the shard directory, the one-deck-per-point renderer, `index.tsv` and the Tcl
# random number generator -- and it creates no widget at all: the campaign
# editor, the progress readout and the result table are Stage 11 task 2.
# ⚠ AND IT IS THE THIRD SUITE IN `hcases` THAT REALLY STARTS A SIMULATOR, ON
# BOTH BINARIES. Its section EE runs a four-point campaign on apt 45.2 AND on
# the fork and checks the measurement column against PHYSICS rather than a
# fixture -- the two points whose RC product is equal must agree and the other
# two must not -- then measures the two facts the whole design rests on: that
# `.param x='var(...)'` is **fatal** on 45.2 (`Undefined parameter [var]`,
# `exit(1)`) and works on the fork, and that `setseed` in `<rundir>/.spiceinit`
# is accepted and seeds nothing while the same line in `.control` does. A binary
# that is not there SKIPS with its path printed.
#
# ⚠ AND THE DISPLAY ARM IS WHERE THE CANVAS IS. Section GC loads a real
# schematic and asks `xschem hilight_netname` to light the nodes `CKTncDump`
# starred; there is no canvas at all under `--nogui`, so a suite that ran only
# headless would report the whole of §10a green while lighting nothing.
#
# ⚠ `test_ase_campaign_gui_1464` IS IN **BOTH** LISTS, AND THE MEASUREMENT SAYS
# WHY. Stage 11 task 2 is the SURFACE -- the campaign dialog, the axis editor
# built from the adapter's own field declarations, the `k/N` progress readout,
# the Stop, and §11c's result table with its histogram, its statistics and its
# scatter -- so its widget legs exist only under X and self-skip without one.
# Measured 2026-09-14 from the `RESULT:` line: **78 checks headless, 156 on the
# dev display**. The headless arm is not redundant: sections ST EX RD are where
# §11c's ARITHMETIC is falsified (the sample sigma against the population one,
# a `-` against a zero, `1k` against `string is double`), section RR drives the
# runner through a `/bin/sh` stand-in, and section EE starts a real simulator on
# BOTH binaries on BOTH arms.
# ⚠ AND IT IS THE FOURTH SUITE IN `hcases` THAT REALLY STARTS A SIMULATOR, ON
# BOTH BINARIES. Its section EE runs a three-point resistive-divider campaign on
# apt 45.2 AND on the fork and checks the measurement column against PHYSICS --
# v(out) = 1k/(rtop+1k), so 0.5 / 0.25 / 0.1 -- and then checks the panel's mean,
# sigma, median, histogram and yield against THAT column rather than a fixture.
# A binary that is not there SKIPS with its path printed.
#
# ⚠ AND THE DISPLAY ARM IS WHERE THE CANVAS IS, AGAIN AND MORE SO: the histogram
# and the scatter are the first canvases ASE-L has ever drawn, and `--nogui` has
# no canvas at all. Row GT5 is the one that measures them being THEMED, which is
# a defect a headless arm cannot see and which a `_theme_widget` with no `Canvas`
# arm shipped until this suite existed.
#
# ⚠ `test_ase_trnoise_gui_1467` IS IN **BOTH** LISTS, FOR 1460's AND 1464's
# REASON. Stage 13 task 2 is the SURFACE -- the noise section on the Tran form,
# its Add control, its live readouts, verdicts and seed sentence -- so its widget
# legs exist only under X and self-skip without one: **19 checks headless, 63 on
# the dev display**, measured 2026-09-15. The headless arm is not redundant:
# sections NQ NK NN NO NS NR NZ NC are where the offer is falsified against the
# check the run applies, where the file-size input is read from a header, and
# where the window is linted for simulator words. ⚠ AND ITS SECTION EE STARTS
# BOTH REAL SIMULATORS ON THE DISPLAY ARM ONLY: it types noise into the form,
# presses OK, renders the deck, runs it on apt 45.2 AND the fork, and returns to
# the form to check its file-size estimate against the file that run wrote.
set dcases [list "headless/test_op_annot" "headless/test_annot_show_menu" \
                 "headless/test_annot_stale_0684" \
                 "headless/test_annot_blank_cause_0909" \
                 "headless/test_lib_new_path_guards_0799" \
                 "headless/test_ase_simdlg_0937" \
                 "headless/test_ase_optsheet_1441" \
                 "headless/test_ase_conv_gui_1460" \
                 "headless/test_ase_campaign_gui_1464" \
                 "headless/test_ase_trnoise_gui_1467" \
                 "headless/test_ase_simwin_variant_1471"]
## ---------------------------------------------------------------------------
## THE VERDICT NAMES ITSELF, AND NOBODY IS REFUSED (ruling R1, re-decided
## 2026-09-17; doc/claude/harness_concurrency_batch/DECISIONS.md)
## ---------------------------------------------------------------------------
## `results.log` is the name CLAUDE.md's reading instructions, doc/claude/ledger/
## crew.js and the user all spell, so it stays exactly where it is. What changed
## is that NO RUN WRITES THROUGH IT: each run fills its own `results.<pid>.log`
## and copies that onto the canonical name when it is complete. The canonical
## file therefore always holds ONE run's whole answer -- the most recent
## completed one -- instead of a mixture or a truncation, and two runs never
## contend for the file they are still filling.
##
## ⚠ THE PREVIOUS DESIGN REFUSED THE SECOND RUN AND THE USER REJECTED THAT
## SHAPE: "Why not make it fault-tolerant and find a way for both runs to
## proceed? Innovation and progress are about having one's cake and eating it."
## They were right. The constraint the whole choice rested on turned out to be a
## FILENAME CONVENTION, not a property of the system.
##
## ⚠ THROUGHPUT IS NOT THE REASON, AND THE SIGN DEPENDS ON THE WORKLOAD. What
## this buys is that no crew is ever told its verification cannot run right now.
## Anyone who reads it as a speed optimisation will reach for it in the wrong
## place -- which is why the two measurements below are given together: they
## disagree in SIGN, so either one quoted alone is a claim about the other.
##   * a staggered pair of golden CASES: both answers at 64.4 s concurrent
##     against 53.7 s back-to-back -- 20% WORSE, because `open_close` already
##     fans out 16 xargs workers, so a second copy is pure contention.
##   * a staggered pair of FULL T1 runs: both answers at 435 s concurrent
##     against 771 s back-to-back -- ~44% BETTER, because a full run has long
##     serial stretches that interleave into this 20-core box's idle cores. Each
##     individual run still costs ~12% more wall (426-431 s vs 382-389 s).
## Measured 2026-09-17, doc/claude/harness_concurrency_batch/receipts/V4.md.
## The banner below reports the FULL-T1 figures, because a second run of this
## driver is a full T1 -- it said "20% SLOWER" until V4 measured it back-to-back
## rather than deriving it, and that sentence was printed to every crew.
set log_fn     "results.log"          ;# canonical: the most recent COMPLETED run
set run_log_fn "results.[pid].log"    ;# this run's own answer, never shared

## The three running totals the trailer reports.
## ⚠ NONE OF THEM EXISTED. summarize_all returned nothing and its num_fail was
## local, so this driver has never known its own answer -- which is why a
## trailer had to be BUILT rather than merely printed, and why every reader has
## had to re-derive the count by grepping the file afterwards.
set t1_cases    0   ;# cases ENTERED -- one per "Start ..." line
set t1_blocks   0   ;# "Total num fail:" blocks written into the verdict
set t1_failures 0   ;# counted failures: the number whose baseline is ZERO

## $fn is the file to READ; $label is the name to PRINT as the block header.
##
## ⚠ THEY ARE SEPARATE ARGUMENTS ON PURPOSE, AND THIS IS ISSUE 1478 §3's TRAP.
## The per-case file NAME GOES INTO THE VERDICT -- this proc's first act is to
## write it as the block header. Pid-qualify the read name naively and every
## block header in results.log grows a pid: the verdict's CONTENTS change, the
## byte-determinism a green run has today is gone, and any reader keying on the
## literal `headless/<name>.disp.log` stops matching.
##
## 1478 proposed publishing each log back to its canonical name BEFORE
## summarizing. That fixes the header and PUTS THE RACE BACK: between the rename
## and the read, the other run can publish its own file onto that same name and
## be scored instead. Reading the private name while printing the public one is
## what closes both at once, and it is one extra argument.
proc summarize_all {fn fd {label {}}} {
  if {$label eq {}} { set label $fn }
  incr ::t1_blocks
  puts $fd "$label"
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
    puts $fd "HARNESS: $label missing ($fn) -- case produced no log (never ran?): FAIL"
    puts $fd "Total num fail: 1"
    set num_fail 1
  }
  incr ::t1_failures $num_fail
  return $num_fail
}

source test_utility.tcl  ;# defines $xschem_cmd (used by the headless cases below) + helpers
source banner_rule.tcl   ;# banner_complete / banner_died / regression_case_failed (issue 0689)

## ⚠ THE CASES WRITE THEIR OWN LOGS, IN THEIR OWN PROCESSES. `tclsh
## open_close.tcl` is a separate pid, so this driver and that case cannot both
## reach for `[pid]` and get the same answer -- the name has to be AGREED.
## print_results reads T1_LOG_TAG out of the environment and t1_run_file (both
## in test_utility.tcl) spells the rule once for both sides. Set before the
## first case starts, and inherited by every child of this interpreter.
set ::env(T1_LOG_TAG) [pid]

## Restore a canonical name from this run's private one, after the verdict for
## that case is already computed. Same contract as publish_results
## (test_utility.tcl): nothing here can change a result, so a failure is a
## warning and never a death -- the file simply stays under its per-run name.
## ⚠ RENAME, NOT COPY, for the per-case logs: the private name is scratch once
## it has been scored, and leaving 83 of them per run behind would be litter in
## a tree that has already paid for litter (issue 1480). The VERDICT is the
## opposite case and is copied, for the reason given where it is published.
proc t1_publish {priv canon} {
  if {$priv eq $canon || ![file exists $priv]} { return 0 }
  if {[catch {file rename -force $priv $canon} e]} {
    puts "WARNING: could not publish $priv as $canon ($e) -- this run's copy stays there"
    return 0
  }
  return 1
}

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

## One header field value, made safe to print (DECISIONS D6). A value with a
## newline in it would start a line of its own, and one ending in `FAIL` would
## make T1-RUN-BEGIN score itself -- so every whitespace or control character
## becomes `_`, and an empty value becomes `-` so the field is never blank.
## ⚠ AND NO VALUE MAY CARRY SENTINEL TEXT (DECISIONS D13.17): `T1-RUN-` becomes
## `T1_RUN_`. The in-tree readers anchor `^T1-RUN-END `, so a header could never
## be mistaken for a trailer by them -- but the round-1 regression refuter put
## `T1-RUN-END cases=87 ...` inside a hostile $XSCHEM and got it into a KILLED
## run's header, where an ad-hoc unanchored `grep T1-RUN-END` (the natural thing
## to type) takes that run as finished.
proc t1_hdr_word {v} {
  regsub -all {[[:space:][:cntrl:]]} $v _ v
  set v [string map {T1-RUN- T1_RUN_} $v]
  if {$v eq {}} { set v - }
  return $v
}

## What `binary=` names (DECISIONS D6, D13.10): the program the cases will
## actually run, resolved the way `exec` resolves it -- auto_execok, then made
## absolute. The field exists for the F10 case (no src/xschem, an installed
## xschem on PATH), and the round-1 header said `binary=xschem` there: the bare
## word, exactly the one case where the reader needs the path. A name that does
## not resolve says so rather than posing as a path.
proc t1_binary_path {cmd} {
  set r [auto_execok $cmd]
  if {[llength $r] == 0} { return "unresolved:$cmd" }
  return [file normalize [lindex $r 0]]
}

## ---------------------------------------------------------------------------
## A PRIVATE Xvfb FOR THE DISPLAY ARM (DECISIONS D8 step 3)
## ---------------------------------------------------------------------------
## Returns {num env-prefix xvfb-pid wm} on success, {} with ::t1_xvfb_why set on
## failure -- `noxvfb` meaning no Xvfb is installed, which is the ONE case the
## arm may report as NODISPLAY.
##
## ⚠ IT IS NUMBERED FROM 100 UP, NEVER `xvfb-run -a`, which starts at :99 and so
## collides with the dev display (F36/0956), and two concurrent T1s can race for
## one number. The server's own lock file settles that race: a server that
## loses it exits at once and the next number is tried.
## ⚠ IT RECORDS ITS PID BEFORE WAITING FOR IT, in the run's own throwaway
## (`.xvfb.pid`), so that a T1 killed at any later instant leaves a record the
## next run's sweep (t1_home_sweep) kills it from. A second copy, in a
## devdisplay-shaped state dir `.xvfb/`, is what lets `devdisplay.sh exec` route
## to it -- so DISPLAY is set per exec and never in this process's ::env, which
## headless cases would otherwise inherit (some spawn xschem without --nogui).
set t1_xvfb_why {}

## ---------------------------------------------------------------------------
## THE PRIVATE DISPLAY'S REAPER (DECISIONS D13.15)
## ---------------------------------------------------------------------------
## A T1 that is killed -9 (or OOM-killed, or loses its terminal: Xvfb survives
## a SIGHUP, it only resets) never reaches its own kill, and the round-1
## regression refuter measured the private Xvfb and openbox then living on,
## reparented to init, holding their lock, until some LATER armed run's sweep
## found them 305 s on -- "no leak" only if somebody runs again. So a small
## detached reaper watches every attempt at a private server. It asks whether
## its owner is still THIS process -- the pid AND its start time, because a pid
## alone recycles -- and when the owner is gone it stops the WM and the server
## and exits. It exits on its own too, as soon as the server is gone (the normal
## path: the owner killed it). It kills only what it can identify: a process
## carrying this attempt's tag (below). The next run's sweep stays the backstop,
## by the sweep's own rule (D13.7): the program's name AND a HOME in its
## /proc/<pid>/environ that is exactly the run directory.
## ⚠ `env -i PATH=...`: it inherits no HOME and none of the harness variables,
## so nothing that looks for a process by this run's HOME mistakes it for part
## of the run -- and `setsid`, where there is one, so that a signal to T1's
## process group (a terminal's hangup) does not take the reaper with it.
## A ZOMBIE OWNER IS A DEAD ONE: a T1 killed -9 lingers in /proc as state Z,
## start time intact, until its parent reaps it -- which a parent that is not a
## shell may not do for a long time (measured: the reaper waited on one for
## over 20 s in row H6 of test_home_isolation.tcl before this line).
## ⚠ IT STARTS BEFORE THE SERVER IS EXEC'D, AND KNOWS IT BY A TAG (D17.7, D20.5).
## Round 2 started it after the up-check, and the round-2 regression refuter
## measured that window at 130-138 ms: a T1 killed -9 inside it left Xvfb :100
## serving for five minutes. Round 3 started it the instant `exec` returned the
## server's pid -- which still left a window, sub-millisecond but real, between
## the exec and the reaper's fork in which a killed T1 left a server that
## nothing watched and nothing recorded (the round-3 regression refuter read it
## off the source; the sweep kills only a RECORDED pid). So now, as the shell
## arm does (xvfb_arm.sh, XSCHEM_TEST_XVFB_TAG), the reaper is started FIRST,
## with a tag unique to this attempt, and the server and its WM are exec'd with
## XSCHEM_TEST_T1_XVFB_TAG=<tag> in their environment. There is then no instant
## at which a server of this run exists with nobody watching: until the record
## names it, the reaper finds it by the tag.
## Its three phases:
##   1. wait (bounded, 10 s) for THIS attempt's server -- the pid the record
##      names, argv[0] Xvfb AND carrying the tag -- watching the owner meanwhile;
##      an owner alive at the end of the wait with no server means the exec
##      failed, and the reaper simply exits;
##   2. while the owner lives, check every $poll s (T1_XVFB_REAPER_POLL, default
##      5) that the server is still there; the normal exit is the owner having
##      stopped it;
##   3. once the owner is gone, stop EVERYTHING carrying the tag -- Xvfb, the
##      WM, and a server still in its `env` stage (the tag is then an argv word)
##      -- rescanning until the scan comes back empty twice, then remove the
##      display's lock if it names a server it stopped.
## Identity is the tag (DECISIONS D13.7): nothing else on the machine carries it.
## ⚠ The poll only bounds how long an ABANDONED attempt's reaper would linger if
## nobody stopped it (t1_private_reaper_stop does, synchronously), and how long a
## killed owner goes unnoticed. Row H7b of test_home_isolation.tcl sets it to 60
## so that a reaper left behind is still there to be seen (the round-3 S14 row).
## ⚠ EACH REAPER RECORDS ITSELF IN ITS OWN FILE, `.xvfb/reaper.<its pid>.pid`, and
## removes it when it exits: a lost race makes two attempts, so two reapers, and
## one shared `reaper.pid` named whichever wrote LAST -- not necessarily the one
## still running (t1_home_kill_xvfb stops every one it finds recorded).
## Positional: $1 owner pid, $2 its start time, $3 run dir, $4 the attempt's
## tag, $5 display number, $6 the configured WM's name (or none), $7 the poll.
set t1_reaper_sh {
o=$1 ost=$2 rd=$3 tg=$4 n=$5 wn0=${6:-none} poll=${7:-5}
case "$poll" in ''|*[!0-9]*|0) poll=5 ;; esac
echo $$ > "$rd/.xvfb/reaper.$$.pid" 2>/dev/null
st() { s=$(cat "/proc/$1/stat" 2>/dev/null) || return 1; s=${s##*) }; case "$s" in Z*) return 1 ;; esac; set -- $s; printf '%s' "${20}"; }
tagged() {
  tr '\0' '\n' < "/proc/$1/environ" 2>/dev/null | grep -qxF "XSCHEM_TEST_T1_XVFB_TAG=$tg" && return 0
  tr '\0' '\n' < "/proc/$1/cmdline" 2>/dev/null | grep -qxF "XSCHEM_TEST_T1_XVFB_TAG=$tg"
}
ours() {
  s=$(cat "/proc/$1/stat" 2>/dev/null) || return 1
  s=${s##*) }; case "$s" in Z*) return 1 ;; esac
  a=$(tr '\0' '\n' < "/proc/$1/cmdline" 2>/dev/null | head -n 1)
  [ -n "$2" ] && [ "${a##*/}" = "$2" ] || return 1
  tagged "$1"
}
bye() { rm -f "$rd/.xvfb/reaper.$$.pid"; exit 0; }
sp=
trap '[ -n "$sp" ] && kill $sp 2>/dev/null; exit 0' TERM
xp=
i=0
while [ $i -lt 100 ]; do
  [ "$(st "$o")" = "$ost" ] || break
  x=$(tr -cd 0-9 < "$rd/.xvfb.pid" 2>/dev/null)
  if [ -n "$x" ] && ours "$x" Xvfb; then xp=$x; break; fi
  sleep 0.1; i=$((i+1))
done
if [ "$(st "$o")" = "$ost" ]; then
  [ -n "$xp" ] || bye
  while :; do
    [ "$(st "$o")" = "$ost" ] || break
    ours "$xp" Xvfb || bye
    sleep "$poll" & sp=$!; wait $sp; sp=
  done
fi
w15=$(printf '%s' "${wn0##*/}" | cut -c1-15)
k=TERM r=0 e=0 xs=
while [ $r -lt 14 ]; do
  f=
  for d in /proc/[0-9]*; do
    c=; read -r c < "$d/comm" 2>/dev/null
    case "$c" in Xvfb|env) ;; *) [ "$wn0" != none ] && [ -n "$c" ] && [ "$c" = "$w15" ] || continue ;; esac
    p=${d#/proc/}
    [ "$p" != "$$" ] || continue
    tagged "$p" || continue
    f="$f $p"
    [ "$c" = Xvfb ] && xs="$xs $p"
    kill -$k "$p" 2>/dev/null
  done
  if [ -z "$f" ]; then e=$((e+1)); [ $e -ge 2 ] && break; else e=0; fi
  [ $r -ge 6 ] && k=KILL
  sleep 0.5; r=$((r+1))
done
lk=$(tr -cd 0-9 < "/tmp/.X$n-lock" 2>/dev/null)
for x in $xs; do
  if [ "$lk" = "$x" ] && [ -z "$(st "$x")" ]; then rm -f "/tmp/.X$n-lock"; fi
done
bye
}
proc t1_private_reaper {rd tag n {wm none}} {
  if {![file isdirectory /proc/self]} { return }
  set ost [t1_self_starttime]
  if {![string is integer -strict $ost]} { return }
  set path /usr/bin:/bin
  if {[info exists ::env(PATH)] && $::env(PATH) ne {}} { set path $::env(PATH) }
  set sid {}
  if {[auto_execok setsid] ne {}} { set sid setsid }
  set poll 5
  if {[info exists ::env(T1_XVFB_REAPER_POLL)] && [string is integer -strict $::env(T1_XVFB_REAPER_POLL)]
      && $::env(T1_XVFB_REAPER_POLL) >= 1 && $::env(T1_XVFB_REAPER_POLL) <= 3600} {
    set poll $::env(T1_XVFB_REAPER_POLL)
  }
  set rp {}
  catch {set rp [exec env -i PATH=$path {*}$sid sh -c $::t1_reaper_sh xschem-t1-reaper [pid] $ost $rd $tag $n [file tail $wm] $poll \
           </dev/null >/dev/null 2>/dev/null &]}
  return $rp
}
## This process's start time (field 22 of /proc/self/stat), or {}.
proc t1_self_starttime {} {
  if {[catch {set f [open /proc/[pid]/stat r]; set st [read $f]; close $f}]} { return {} }
  return [lindex [string range $st [expr {[string last ")" $st] + 2}] end] 19]
}
## Stop the reaper of an ATTEMPT this arm abandons (a lost race, a server that
## never answered): it watches a server that is gone and would otherwise linger
## until its next 5 s poll -- measured in four-way concurrent runs as a reaper
## still alive after the run (row H1b). Only the process `exec` returned, and
## only while its own command line still names the marker and this run dir.
proc t1_private_reaper_stop {rp rd} {
  if {![string is integer -strict $rp] || ![t1_home_pid_running $rp]} { return }
  if {[catch {set f [open /proc/$rp/cmdline r]; fconfigure $f -translation binary
              set c [split [read $f] \x00]; close $f}]} { return }
  if {[lsearch -exact $c xschem-t1-reaper] < 0 || [lsearch -exact $c $rd] < 0} { return }
  t1_home_kill $rp
}

proc t1_private_xvfb {dd} {
  set ::t1_xvfb_why {}
  if {[auto_execok Xvfb] eq {}} { set ::t1_xvfb_why noxvfb ; return {} }
  if {![file executable $dd]} {
    set ::t1_xvfb_why "$dd is missing, so nothing could be routed to a private display"
    return {}
  }
  set rd [t1_home_run_dir]
  if {$rd eq {}} {
    set ::t1_xvfb_why "no run directory could be made under [t1_home_root] to record it in"
    return {}
  }
  set sd [file join $rd .xvfb]
  file mkdir $sd
  set scr 1920x1080x24
  if {[info exists ::env(DEVDISPLAY_SCREEN)] && $::env(DEVDISPLAY_SCREEN) ne {}} {
    set scr $::env(DEVDISPLAY_SCREEN)
  }
  set wm openbox
  if {[info exists ::env(DEVDISPLAY_WM)] && $::env(DEVDISPLAY_WM) ne {}} { set wm $::env(DEVDISPLAY_WM) }
  set tried 0
  for {set n 100} {$n < 200} {incr n} {
    if {[file exists /tmp/.X$n-lock] || [file exists /tmp/.X11-unix/X$n]} { continue }
    incr tried
    ## HOME = the run directory that records it, in every mode (D13.7): the
    ## record and the process then name each other, and a sweep or reaper
    ## that finds a pid in the record kills it only if its HOME says so.
    ## ⚠ -noreset (S2c-R2-I). An X server resets when its LAST client goes, and
    ## the up-check below and the WM's claim wait are all short-lived clients
    ## (xdpyinfo, xprop, xlsclients) that come and go before openbox has
    ## connected -- so openbox can arrive in the middle of a reset and die with
    ## "Failed to open the display" (measured: 12 of 360 starts under that exact
    ## client sequence, 0 of 360 with -noreset; H6 saw it as `wm 0`, and the arm
    ## then ran WM-LESS). The persistent dev display never resets either: its
    ## openbox stays connected.
    ## ⚠ THE REAPER FIRST, THEN THE SERVER (D17.7, D20.5; see t1_reaper_sh). The
    ## tag names THIS attempt -- this run, this number, this instant -- and rides
    ## into the server's and the WM's environment, so a T1 killed at any moment
    ## after this line leaves nothing the reaper cannot find, record or no record.
    set tag "t1.[pid].[t1_self_starttime].$n.[clock microseconds]"
    set rp [t1_private_reaper $rd $tag $n $wm]
    if {[catch {exec env HOME=$rd XSCHEM_TEST_T1_XVFB_TAG=$tag Xvfb :$n -screen 0 $scr -nolisten tcp -noreset </dev/null >/dev/null 2>/dev/null &} xp]} {
      t1_private_reaper_stop $rp $rd
      set ::t1_xvfb_why "Xvfb would not start: $xp"
      return {}
    }
    foreach f [list [file join $rd .xvfb.pid] [file join $sd xvfb.pid]] {
      set h [open $f w] ; puts $h $xp ; close $h
    }
    set h [open [file join $sd display] w] ; puts $h :$n ; close $h
    set penv [list env XSCHEM_DEVDISPLAY_DIR=$sd DEVDISPLAY_NUM=$n]
    set up 0
    set lost {}
    for {set i 0} {$i < 100} {incr i} {
      if {![t1_home_pid_running $xp]} { break }
      ## THE LOCK SAYS WHOSE THE NUMBER IS, and it says so before any server
      ## answers: a lock naming another pid means ours lost the race, whether
      ## or not it has exited yet. (devdisplay.sh's `status` now applies the same
      ## rule -- D17.6 -- so it would never call a slow loser up, and waiting
      ## for it to would cost this arm its 10 s bound and then its display.)
      set lk [t1_home_read_int /tmp/.X$n-lock]
      if {$lk ne {} && $lk ne $xp} { set lost $lk ; break }
      if {![catch {exec {*}$penv $dd status >/dev/null 2>/dev/null}]} { set up 1 ; break }
      after 100
    }
    if {$lost eq {} && $up && [t1_home_read_int /tmp/.X$n-lock] ne $xp} { set lost [t1_home_read_int /tmp/.X$n-lock] }
    ## ⚠ "UP" MUST MEAN *OUR* SERVER ANSWERS, AND ONLY ITS LOCK SAYS WHOSE IT IS
    ## (the D13.14 identity rule; S2c-R2-I). `devdisplay.sh status` asks two
    ## separate questions -- is the recorded pid alive and named Xvfb :$n, and
    ## does SOMETHING answer on :$n -- and two runs that pick the same free
    ## number in the same instant get "yes" to both: the server that loses the
    ## lock does not exit at once (measured: still alive 1.5 s later, 3 of 30
    ## synchronized pairs), while the winner's answers. Both runs then called
    ## the winner's display their own, the loser's openbox lost the screen to
    ## the winner's, and the loser's display cases ran on a server the other
    ## run would kill when IT finished. So: the lock must name the pid we
    ## started, or this number went to someone else -- stop ours, try the next.
    if {$lost ne {}} {
      puts "display arm: :$n went to a concurrent run (its lock names $lost, not our $xp); trying the next number"
      t1_home_kill $xp
      t1_private_reaper_stop $rp $rd
      catch {file delete -- [file join $rd .xvfb.pid] [file join $sd xvfb.pid]}
      if {$tried >= 20} { break }
      continue
    }
    if {!$up} {
      catch {file delete -- [file join $rd .xvfb.pid] [file join $sd xvfb.pid]}
      t1_private_reaper_stop $rp $rd
      if {[t1_home_pid_running $xp]} {
        ## Running but never answering is not a lost race, and trying twenty
        ## more numbers would cost the run minutes to learn the same thing.
        t1_home_kill $xp
        set ::t1_xvfb_why "Xvfb :$n started but did not answer within 10 s"
        return {}
      }
      ## It exited: another server took :$n first. Try the next number.
      if {$tried >= 20} { break }
      continue
    }
    set wmname none
    if {$wm ne {none} && [auto_execok $wm] ne {}} {
      ## Short-lived like its server, and harness state rather than anything
      ## under test, so it gets the RUN's directory as its home in every mode
      ## -- including XSCHEM_TEST_HOME=real, where HOME is the tester's own and
      ## openbox would otherwise leave ~/.cache/openbox there (measured). Its
      ## cache goes with the run directory.
      if {![catch {exec env -u XDG_CACHE_HOME -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_STATE_HOME \
                        HOME=$rd DISPLAY=:$n XSCHEM_TEST_T1_XVFB_TAG=$tag $wm </dev/null >/dev/null 2>/dev/null &} wp]} {
        set h [open [file join $sd wm.pid] w] ; puts $h $wp ; close $h
        set h [open [file join $sd wm] w] ; puts $h [file tail $wm] ; close $h
        set wmname [file tail $wm]
        ## A toplevel mapped before the WM owns the screen is never reparented
        ## (devdisplay.sh's _wm_claimed), so wait for the claim, bounded.
        if {[auto_execok xprop] ne {}} {
          for {set i 0} {$i < 50} {incr i} {
            if {![catch {exec xprop -display :$n -root _NET_SUPPORTING_WM_CHECK 2>/dev/null} o] \
                  && [string match {*window id #*} $o]} { break }
            if {![t1_home_pid_running $wp]} { set wmname "none ($wm died)" ; break }
            after 100
          }
        }
      }
    }
    set h [open [file join $sd screen] w] ; puts $h $scr ; close $h
    return [list $n $penv $xp $wmname]
  }
  set ::t1_xvfb_why "Xvfb is installed but no display number from :100 up could be started ($tried tried)"
  return {}
}

## ---------------------------------------------------------------------------
## THE PUBLISH LOCK -- A SAFETY NET, NOT A GATE (issue 1476 face 4; 0955, 0905)
## ---------------------------------------------------------------------------
## HISTORY, because it is what the code below is shaped by. The verdict file was
## opened mode `w` -- fixed name, truncate, no lock -- so two runs in one tree
## destroyed each other's ANSWER. Measured 2026-09-16 with two copies of this
## driver: the file ends up 13268 bytes, zero NUL bytes, the first run's verdict
## complete and perfectly well-formed, and the second run's ENTIRE verdict simply
## never exists while that run exits 0 printing its Finish lines. Nothing is
## corrupted; a whole run's evidence is gone. That is the DANGEROUS direction --
## the other three faces of 1476 are loud, this one manufactures a phantom PASS
## in the one file CLAUDE.md calls "THE ONLY PLACE THE ANSWER IS". And "I started
## first" was never a defence: measured over ten pairs, nine erased the second
## run and one erased the FIRST.
##
## ⚠ THE FIRST FIX WAS A LOCK THAT REFUSED THE SECOND RUN, AND IT IS GONE. Under
## ruling R1 as re-decided, both runs proceed: each fills its own
## `results.<pid>.log`, so while a run is happening there is NOTHING SHARED left
## to serialise. A lock across a whole regression run was protecting a filename
## convention as if it were physics.
##
## ⚠ WHAT IS KEPT, AND WHY IT IS KEPT RATHER THAN DELETED. One act is still
## shared: copying a FINISHED verdict onto the canonical name. The lock now
## brackets exactly that -- a sub-second critical section instead of a ~410 s
## one -- so the canonical file can never be a mixture of two runs' bytes. And
## the evidence-based stale-lock logic below is the only correct code in this
## tree for "is that pid still the thing that took this": a bare `kill -0`
## answers yes for a RECYCLED pid. Deleting the block would throw that away to
## save nothing.
##
##     T1_LOG_LOCK_WAIT  seconds to wait for the PUBLISH lock (default 60).
##                       ⚠ ITS MEANING CHANGED. It used to be "seconds to queue
##                       behind a whole live regression run before being
##                       refused", default 0 because nobody should wait 400 s by
##                       accident. Nothing queues behind a run any more, so the
##                       only thing it can now wait for is a file copy, and a
##                       default of 0 would make the lock decorative.
##     T1_LOG_LOCK_TTL   seconds after which a lock is broken even though some
##                       process still holds the owner's pid; 0 disables it.
##                       The pid AND its /proc cmdline are the real evidence;
##                       this is only the backstop for a recycled pid. ⚠ ALSO
##                       RETUNED, 14400 -> 300: it had to outlast a whole run,
##                       and now it only has to outlast a copy.
##     T1_VERDICT_KEEP   seconds to keep a DEAD run's results.<pid>.log before
##                       sweeping it (default 86400; 0 disables sweeping).
##
## ⚠ A LOCK MUST NEVER BECOME THE REASON T1 DOES NOT RUN. Every failure of the
## locking machinery itself FAILS OPEN: a lock whose owner is gone is broken on
## evidence, and one that can be neither taken nor broken lets the run proceed
## UNLOCKED with a warning. A tree that cannot be tested is worse than a tree
## tested without a lock.
##
## ⚠ AND `file mkdir` IS NOT A LOCK IN TCL. tests/headless/gui_gate.sh:169 uses
## the mkdir idiom, which is atomic in /bin/sh because mkdir(2) fails on an
## existing directory. Tcl's `file mkdir` SUCCEEDS silently on one (measured on
## tcl 8.6.17: rc 0, no error), so that shape ported here would hand the lock to
## both runs and read as correct. `open ... {WRONLY CREAT EXCL}` is the Tcl
## primitive that carries O_EXCL's guarantee, and it is what this uses.
proc t1_lock_env {name dflt} {
  if {[info exists ::env($name)]} {
    set v [string trim $::env($name)]
    if {[string is integer -strict $v] && $v >= 0} { return $v }
  }
  return $dflt
}

## Is $p a live process OTHER than us, still running what the lock owner recorded?
## A bare `kill -0` answers yes for a RECYCLED pid, which is how an age-only rule
## comes to break a healthy run's lock. On Linux the cmdline settles it; the tag
## is the owner's own script name, so this works for a copy of this driver under
## another name (which is exactly what the 1476 suite runs).
proc t1_lock_owner_alive {p tag} {
  if {![string is integer -strict $p] || $p <= 0} { return 0 }
  if {$p == [pid]} { return 0 }
  if {[file isdirectory /proc]} {
    if {![file isdirectory /proc/$p]} { return 0 }
    if {$tag eq {}} { return 1 }
    set cl {}
    if {[catch {set f [open /proc/$p/cmdline r]; set cl [read $f]; close $f}]} { return 1 }
    return [expr {[string first $tag [string map [list \x00 { }] $cl]] >= 0}]
  }
  return [expr {[catch {exec kill -0 $p}] ? 0 : 1}]
}

## Take the lock. Returns {} when we own it, or a sentence naming the holder.
## ::t1_lock_waited is the pid we queued behind, 0 if we never waited -- the
## caller needs it to know whether the verdict on disk is a live run's.
set t1_lock_waited 0
proc t1_lock_take {lf waitsecs ttl} {
  set deadline [expr {[clock seconds] + $waitsecs}]
  set tag [file tail [info script]]
  if {$tag eq {}} { set tag tclsh }
  set breaks 0
  set said 0
  while {1} {
    if {![catch {open $lf {WRONLY CREAT EXCL} 0600} fh]} {
      catch {puts $fh [list [pid] [clock seconds] $tag]}
      catch {close $fh}
      return {}
    }
    set own {}
    catch {set f [open $lf r] ; set own [string trim [read $f]] ; close $f}
    set opid {} ; set oep 0 ; set otag {}
    catch {set opid [lindex $own 0] ; set oep [lindex $own 1] ; set otag [lindex $own 2]}
    if {![string is integer -strict $oep]} { set oep 0 }
    set age   [expr {[clock seconds] - $oep}]
    set alive [t1_lock_owner_alive $opid $otag]
    if {!$alive || ($ttl > 0 && $age >= $ttl)} {
      incr breaks
      if {$breaks > 3} {
        puts "WARNING: $lf can be neither taken nor broken after $breaks attempts."
        puts "WARNING: running UNLOCKED -- a second run in this tree can still erase this run's verdict."
        return {}
      }
      if {$alive} {
        puts "NOTE: breaking verdict lock $lf -- owner pid $opid is alive but the lock is ${age}s old, past the ${ttl}s TTL (a recycled pid)."
      } else {
        puts "NOTE: breaking stale verdict lock $lf -- owner pid [expr {$opid eq {} ? {?} : $opid}] is no longer running. A killed run leaves this behind."
      }
      catch {file delete -force $lf}
      continue
    }
    if {[clock seconds] >= $deadline} { return "held by pid $opid ($otag), taken [clock format $oep -format {%Y-%m-%d %H:%M:%S}], ${age}s ago" }
    if {!$said} {
      set said 1
      set ::t1_lock_waited $opid
      puts "WAITING for the verdict lock: pid $opid is running $otag here. Queueing for up to ${waitsecs}s (T1_LOG_LOCK_WAIT)."
    }
    after 500
  }
}

set lock_file "$log_fn.lock"

## Verdicts of runs that are no longer alive get swept, or one file per T1 run
## accumulates in tests/ for ever (this tree has already paid for litter --
## issue 1480).
## ⚠ THE FAILURE DIRECTION MUST BE "A LEFTOVER SURVIVES", never "a live run's
## answer is deleted", which is why a pid with /proc present is skipped even if
## it is not a regression run at all. Same contract as sweep_dead_run_dirs, and
## the age floor is there so a crew that finished ten minutes ago can still be
## asked what it found.
proc t1_sweep_verdicts {keep} {
  if {$keep <= 0 || ![file isdirectory /proc/[pid]]} { return {} }
  set now [clock seconds]
  set swept {}
  foreach f [glob -nocomplain -- results.*.log] {
    if {![regexp {^results\.([0-9]+)\.log$} [file tail $f] -> p]} { continue }
    if {$p == [pid] || [file exists /proc/$p]} { continue }
    if {[catch {file mtime $f} m]} { continue }
    if {$now - $m < $keep} { continue }
    if {![catch {file delete -force $f}]} { lappend swept [file tail $f] }
  }
  if {[llength $swept]} {
    puts "swept [llength $swept] dead run verdict(s): $swept"
  }
  return $swept
}

## Which OTHER regression runs are filling a verdict in this tree right now?
## ⚠ THE PER-RUN VERDICT IS ITSELF THE LIVENESS RECORD -- a `results.<pid>.log`
## whose pid is still alive. No registry, no second file to leak, and it is the
## same evidence a reader uses afterwards to decide whose answer a file is.
proc t1_live_runs {} {
  set live {}
  if {![file isdirectory /proc]} { return $live }
  foreach f [glob -nocomplain -- results.*.log] {
    if {![regexp {^results\.([0-9]+)\.log$} [file tail $f] -> p]} { continue }
    if {$p == [pid]} { continue }
    if {[file isdirectory /proc/$p]} { lappend live $p }
  }
  return $live
}

t1_sweep_verdicts [t1_lock_env T1_VERDICT_KEEP 86400]

## ⚠ A LIVE RUN IS ANNOUNCED, NEVER REFUSED. The operator needs to know which
## file is theirs, because the canonical one is about to be written twice; that
## is the whole of what the old refusal was really for, and it can be said
## without stopping anybody.
set t1_others [t1_live_runs]
if {[llength $t1_others]} {
  puts "############################################################"
  puts "NOTE: another regression run is live in this tree (pid: [join $t1_others {, }])."
  puts "  BOTH RUNS PROCEED. Nobody waits and nobody is refused (ruling R1)."
  puts ""
  puts "  YOUR answer is $run_log_fn. $log_fn will hold whichever run"
  puts "  finishes LAST, and every verdict carries a T1-RUN-BEGIN/T1-RUN-END"
  puts "  pair naming its pid -- so read the trailer, not the filename."
  puts ""
  puts "  THIS IS NOT A THROUGHPUT OPTIMISATION. What it buys is that neither"
  puts "  crew is turned away; speed is a side effect and its SIGN depends on"
  puts "  the workload. Measured 2026-09-17 on a full T1 pair: both answers in"
  puts "  435 s concurrent against 771 s back-to-back (~44% faster), though each"
  puts "  run individually costs ~12% more. On a single-CASE pair it was 20%"
  puts "  SLOWER. Do not reach for concurrency to go faster."
  puts "############################################################"
}

set t1_started [clock seconds]
set a [catch "open \"$run_log_fn\" w" fd]
if {!$a} {
## ⚠ THIS ONE LINE IS LOAD-BEARING AND IT LOOKS LIKE HOUSEKEEPING. There was no
## `fconfigure` and no `flush` anywhere in this driver, so the verdict channel
## was FULL-BUFFERED AT 4096 B against a ~4785-byte verdict. That is why issue
## 1477's killed runs leave a 0-BYTE file rather than a proportional prefix: the
## typical outcome, not an extreme one. The trailer below survives buffering
## either way (it is written last, then closed); the HEADER does not, and the
## header is the half that says WHOSE answer a file is. Without this line the
## sentinels inherit the exact hole they were added to close.
fconfigure $fd -buffering line
## ⚠ NEITHER SENTINEL MAY END IN `FAIL`/`GOLD?`/`RESULT?` OR BEGIN WITH `FATAL`.
## Those are summarize_all's four counted shapes, and every reader of this file
## -- crew.js, CLAUDE.md's greps, a human -- applies them to the whole verdict. A
## sentinel that scored itself would be a phantom red manufactured by the fix.
## Row V4a of test_regression_concurrency_1476.tcl holds that by measurement.
## ⚠ `home=` AND `binary=` ARE THE TWO FIELDS A USER CONTROLS (DECISIONS D6):
## XSCHEM_TEST_HOME picks the first and $XSCHEM spells the second. Both sit
## BEFORE `canonical=`, which stays last and is ours, and both go through
## t1_hdr_word -- see there for why.
puts $fd "T1-RUN-BEGIN pid=[pid] script=[file tail [info script]]\
 start=[clock format $t1_started -format {%Y-%m-%d %H:%M:%S}]\
 planned_cases=[expr {[llength $tcases] + [llength $hcases] + [llength $dcases] + 1}]\
 verdict=$run_log_fn home=[t1_hdr_word [t1_home_kind]] binary=[t1_hdr_word [t1_binary_path $xschem_cmd]]\
 canonical=$log_fn"
foreach tc $tcases {
    puts "Start source ${tc}.tcl"
    incr t1_cases
    ## ⚠ PER-RUN NAMES (issue 1478). ${tc}.log is written by the CASE's own
    ## process via print_results, which agrees on the spelling through
    ## T1_LOG_TAG; ${tc}_output.txt is written by the redirection below. Both
    ## were one fixed slot per case NAME rather than per RUN.
    ## The sharpest face lived right here: `file delete -force ${tc}.log` at the
    ## START of the next case could land between the other run's case exiting and
    ## that run's summarize_all, which then took the missing-log branch --
    ## `case produced no log (never ran?): FAIL`, A COUNTED FAILURE THAT NEVER
    ## HAPPENED, in the one suite whose baseline is ZERO.
    set tclog [t1_run_file $tc .log]
    set tcout [t1_run_file $tc _output.txt]
    # Drop any previous run's log FIRST (issue 0147): nothing else deletes it, so
    # a stale <case>.log left on disk was re-grepped and its old FAILs replayed as
    # if they were this run's -- and it survives a "reproduce on a clean baseline"
    # recheck, which makes phantom failures look confirmed.
    file delete -force $tclog
    set childcode 0
    set tccmd [concat $t1_pre [list tclsh ${tc}.tcl]]
    if {[catch {eval exec $tccmd > $tcout} msg opt]} {
      set ec [dict get $opt -errorcode]
      set childcode [expr {[lindex $ec 0] eq "CHILDSTATUS" ? [lindex $ec 2] : 1}]
      puts "Something seems to have gone wrong with $tc, but we will ignore it: $msg"
    }
    ## A kill leaves the case log as whatever the case had written by then, which
    ## summarize_all would read as an ordinary partial result. Say so instead.
    if {$childcode == 124 || $childcode == 137} {
      set af [open $tclog a]
      puts $af "HARNESS: ${tc} [t1_why $childcode $t1_tmo]: FAIL"
      close $af
      puts "TIMEOUT: ${tc} killed after ${t1_tmo}s"
    }
    ## READ the private name, PRINT the canonical one -- see summarize_all.
    summarize_all $tclog $fd ${tc}.log
    t1_publish $tclog ${tc}.log
    t1_publish $tcout ${tc}_output.txt
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
    incr t1_cases
    ## ⚠ THIS IS THE FILE THE COLLISION WAS REPRODUCED IN, and it is 69 of the
    ## 83 verdict inputs. Measured 2026-09-17 with the tree's own banner_rule.tcl
    ## as the scorer, wrong in BOTH directions: with both children exiting 0 --
    ## the ORDINARY shape, since a suite reporting N failed checks still prints
    ## its banner and exits 0 -- run A's TWO REAL FAILURES were counted as ZERO,
    ## and separately the PASSING run counted a failure it did not earn. The
    ## silent direction is face 4 again, one file upstream of the verdict.
    set hclog [t1_run_file $hc .log]
    set childcode 0
    set hccmd [concat $t1_pre [list $xschem_cmd --nogui --pipe -q --script ${hc}.tcl]]
    if {[catch {eval exec $hccmd > $hclog 2>@1} msg opt]} {
      set ec [dict get $opt -errorcode]
      set childcode [expr {[lindex $ec 0] eq "CHILDSTATUS" ? [lindex $ec 2] : 1}]
    }
    set body ""
    if {![catch {open $hclog r} rf]} { set body [read $rf]; close $rf }
    set sentinel [banner_complete $body]
    set died     [banner_died $body]
    if {[regression_case_failed $childcode $body]} {
      set af [open $hclog a]
      puts $af "HARNESS: ${hc} did not complete cleanly (exit=$childcode, OVERALL_ok=$sentinel, died=$died) -- [t1_why $childcode $t1_tmo]: FAIL"
      close $af
    }
    summarize_all $hclog $fd ${hc}.log
    t1_publish $hclog ${hc}.log
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
  ## ⚠ WHICH DISPLAY THE ARM RUNS ON (DECISIONS D8). This used to be one line,
  ## `exec $dd start`, run with whatever HOME this process had -- which for a
  ## stranger meant a PERSISTENT Xvfb + openbox started into their real home and
  ## never stopped (audit F36), and under a throwaway HOME is exactly how the
  ## orphan holding :99 on the developer's box was made: started with a HOME
  ## that was deleted under it. Now, in order:
  ##   1. attach to the dev display through the carried state dir;
  ##   2. auto-start it ONLY if that state dir already exists (the tester has
  ##      used it before), and only with the PRE-switch environment, so that a
  ##      long-lived display never inherits a HOME that is about to be deleted;
  ##   3. otherwise, or if that start fails (exit 4 on a foreign :99), a PRIVATE
  ##      Xvfb for this run only (t1_private_xvfb), killed when the arm is done;
  ##   4. NODISPLAY only when no Xvfb is installed at all. An Xvfb that is
  ##      installed and will not start is a COUNTED failure: turning a broken
  ##      display into silence is what issue 0891 was.
  ## ⚠ STEP 3 TURNS 11 UNCOUNTED NODISPLAY LINES INTO 11 COUNTED RUNS on every
  ## box without a dev display, which is why it was measured green on the
  ## private arm before it landed (doc/claude/outsider_fixes_batch/receipts/S2c-T.md).
  set dd_state [file join $env(HOME) .claude xschem_dev_display]
  if {[info exists env(XSCHEM_DEVDISPLAY_DIR)] && $env(XSCHEM_DEVDISPLAY_DIR) ne {}} {
    set dd_state $env(XSCHEM_DEVDISPLAY_DIR)
  }
  set dd_env {}
  set dd_why {}
  set dd_where {}
  set dd_st {}
  set dd_alive 0
  ## No display case, no display: a driver whose list is empty (1476's staged
  ## copies) must not start an Xvfb it will never use.
  if {[llength $dcases]} {
    catch {exec $dd status 2>@1} dd_st
    set dd_alive [expr {[string match {*state:*alive*} $dd_st] ? 1 : 0}]
  }
  if {$dd_alive} { set dd_where "attached to the dev display (state dir $dd_state)" }
  if {[llength $dcases] && !$dd_alive && [file isdirectory $dd_state]} {
    set dd_so {}
    catch {exec {*}[t1_home_preswitch_env] $dd start 2>@1} dd_so
    catch {exec $dd status 2>@1} dd_st
    set dd_alive [expr {[string match {*state:*alive*} $dd_st] ? 1 : 0}]
    if {$dd_alive} {
      set dd_where "started the dev display (state dir $dd_state, with the pre-switch HOME)"
    } else {
      puts "display arm: the dev display in $dd_state would not start\
 ([string trim [lindex [split [string trim $dd_so] \n] 0]]) -- using a private Xvfb"
    }
  }
  if {[llength $dcases] && !$dd_alive} {
    set px [t1_private_xvfb $dd]
    if {[llength $px]} {
      lassign $px dd_num dd_env dd_xpid dd_wm
      set dd_alive 1
      set dd_where "PRIVATE Xvfb :$dd_num for this run only (pid $dd_xpid, wm $dd_wm)"
    } else {
      set dd_why $t1_xvfb_why
      set dd_where "NONE -- $dd_why"
    }
  }
  if {[llength $dcases]} { puts "display arm: $dd_where" }
  foreach dc $dcases {
    puts "Start ${dc}.tcl (display arm)"
    incr t1_cases
    ## Per-run name, as for the headless arm (issue 1478): 11 more of the 83.
    set dclog [t1_run_file $dc .disp.log]
    file delete -force $dclog
    if {!$dd_alive} {
      ## ⚠ THIS ARM WRITES ITS OWN BLOCK RATHER THAN CALLING summarize_all, so
      ## the block counter has to be incremented by hand here. Miss it and the
      ## trailer under-reports on every box with no dev display -- which would
      ## make the trailer itself the thing that lies.
      incr t1_blocks
      puts $fd "${dc}.disp.log"
      if {$dd_why eq {noxvfb}} {
        puts $fd "NODISPLAY: ${dc} display arm NOT RUN -- no Xvfb is installed here, so THIS ARM VERIFIED NOTHING. Install Xvfb (the xvfb package) and run again."
        puts $fd "Total num fail: 0"
        puts "NODISPLAY: ${dc} display arm NOT RUN -- this arm verified NOTHING"
      } else {
        puts $fd "HARNESS: ${dc} display arm NOT RUN -- Xvfb is installed but no display could be started ($dd_why): FAIL"
        puts $fd "Total num fail: 1"
        incr t1_failures
        puts "DISPLAY ARM FAILED: ${dc} not run -- $dd_why"
      }
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
    ## ⚠ $dd_env IS EMPTY ON THE DEV DISPLAY and names the private Xvfb's state
    ## dir and number otherwise (D8): the routing is `$dd exec` either way.
    set dccmd [concat $dd_env [list $dd exec] $t1_pre [list $xschem_cmd --pipe -q --logdir $dlogdir --script ${dc}.tcl]]
    if {[catch {eval exec $dccmd > $dclog 2>@1} msg opt]} {
      set ec [dict get $opt -errorcode]
      set childcode [expr {[lindex $ec 0] eq "CHILDSTATUS" ? [lindex $ec 2] : 1}]
    }
    set body ""
    if {![catch {open $dclog r} rf]} { set body [read $rf]; close $rf }
    set sentinel [banner_complete $body]
    set died     [banner_died $body]
    if {[regression_case_failed $childcode $body]} {
      set af [open $dclog a]
      puts $af "HARNESS: ${dc} (display arm) did not complete cleanly (exit=$childcode, OVERALL_ok=$sentinel, died=$died) -- [t1_why $childcode $t1_tmo]: FAIL"
      close $af
    }
    summarize_all $dclog $fd ${dc}.disp.log
    t1_publish $dclog ${dc}.disp.log
    puts "Finish ${dc}.tcl (display arm)"
  }
  ## The private display is this run's alone and nothing after this point needs
  ## it: kill it now rather than at exit. (The dev display, attached or started,
  ## is persistent by design and is never stopped by T1.)
  if {[llength $dd_env]} { catch {t1_home_kill_xvfb [t1_home_run_dir]} }
  # xschemtest.tcl: the broad functional/perf harness. GUARDED (issue 0147) --
  # it used to run AFTER results.log was closed and with no catch, so any failure
  # (e.g. an unresolvable binary) aborted the interpreter with a raw Tcl stack
  # trace and never appeared in the summary at all. Now its outcome is recorded.
  puts "Start xschemtest.tcl"
  incr t1_cases
  set xtlog [t1_run_file stefan_xschemtest .log]
  set xtcmd [concat $t1_pre [list $xschem_cmd --nogui --pipe -q --script xschemtest.tcl]]
  if {[catch {eval exec $xtcmd > $xtlog 2>@1} msg]} {
    ## ⚠ THIS ARM ALSO WRITES ITS OWN BLOCK, so it counts its own block and its
    ## own failure. And note it writes one ONLY WHEN IT FAILS -- which is why the
    ## verdict carries one fewer block than there are cases on a green run. That
    ## arithmetic used to have to be remembered; the trailer now states it.
    incr t1_blocks
    incr t1_failures
    puts $fd "xschemtest.tcl"
    puts $fd "HARNESS: xschemtest.tcl did not run cleanly ($msg): FAIL"
    puts $fd "Total num fail: 1"
    puts "xschemtest.tcl FAILED: $msg"
  }
  t1_publish $xtlog stefan_xschemtest.log
  puts "Finish xschemtest.tcl"
  ## ⚠ THE TRAILER IS THE HALF WORTH MORE THAN THE CONCURRENCY FIX, and it closes
  ## two recorded traps that no amount of locking touches:
  ##
  ##   * THE FOSSIL. A stale results.log reads as a perfect clean sweep. Only its
  ##     mtime ever said otherwise, and receipts plus a commit message in this
  ##     tree already carry a case count taken that way -- one of them a number
  ##     that was INDISTINGUISHABLE from the correct one on the day it was taken.
  ##     A trailer naming pid and end time makes a fossil self-identifying FROM
  ##     CONTENT, which is the only thing a reader actually has.
  ##
  ##   * ISSUE 1477's TRUNCATION HOLE. EVERY PREFIX OF A GREEN RUN IS ITSELF A
  ##     GREEN RUN, because all four counted shapes (FAIL$, GOLD?$, RESULT?$,
  ##     ^FATAL) need a line to EXIST -- verified at 1, 10, 40, 80, 120 and 170
  ##     lines of a real 169-line verdict, zero counted failures at every length.
  ##     "No trailer => did not finish" is decidable where "short file" is not.
  ##
  ## ⚠ AND IT STATES THE ARITHMETIC CLAUDE.md SPELLS OUT BY HAND. `cases` is
  ## Start lines; `blocks` is "Total num fail:" lines, normally one fewer; a
  ## short count is a death even when every line present is green.
  set t1_ended [clock seconds]
  puts $fd "T1-RUN-END pid=[pid] cases=$t1_cases blocks=$t1_blocks\
 counted_failures=$t1_failures elapsed=[expr {$t1_ended - $t1_started}]s\
 end=[clock format $t1_ended -format {%Y-%m-%d %H:%M:%S}]"
  close $fd

  ## ⚠ COPY, DO NOT RENAME. A rename would hand the canonical name over and
  ## DELETE this run's own answer -- which is precisely the "lost cleanly"
  ## outcome this ruling exists to avoid: the second finisher would erase the
  ## first's verdict, tidily instead of mid-write, and the batch would have
  ## traded a loud data loss for a quiet one.
  ##
  ## The lock is taken HERE and nowhere else: one file copy, not a whole run.
  ## It fails open by construction (t1_lock_take returns a sentence rather than
  ## raising), because a lock must never become the reason T1 has no answer.
  set lock_busy [t1_lock_take $lock_file [t1_lock_env T1_LOG_LOCK_WAIT 60] \
                                         [t1_lock_env T1_LOG_LOCK_TTL 300]]
  if {$lock_busy ne {}} {
    puts "NOTE: publishing $run_log_fn as $log_fn WITHOUT the publish lock ($lock_busy)."
    puts "NOTE: both verdicts are complete under their own names; $log_fn is whichever copied last."
  }
  if {[catch {file copy -force $run_log_fn $log_fn} e]} {
    puts "WARNING: could not publish $run_log_fn as $log_fn ($e)."
    puts "WARNING: this run's verdict is COMPLETE and is in $run_log_fn -- read that."
  }
  catch {file delete -force $lock_file}
  puts "VERDICT: this run's answer is $run_log_fn ($t1_failures counted failure(s) over $t1_cases case(s)); published as $log_fn"
} else {
  puts "Couldn't open $run_log_fn to write.  Investigate please."
}
## ⚠ THE OWNER DELETES ITS THROWAWAY HOME HERE, AFTER THE TRAILER (DECISIONS D5)
## -- never before it, because every case and every child of this run lives in
## that HOME until the last one has been scored. A no-op for a nested run (it
## owns nothing), for XSCHEM_TEST_HOME=real or =<dir> (nothing to delete but a
## private display's record), and for XSCHEM_TEST_KEEP_HOME=1 (kept, and said).
## A run that dies before reaching this line is collected by the next run's
## sweep, which also kills a private Xvfb it had recorded.
t1_home_release
## ⚠ NOTHING TO RELEASE HERE ANY MORE, AND THAT IS THE POINT. The lock used to be
## held for the WHOLE RUN and released at this line on both arms. It is now taken
## and dropped around the single file copy above, so by the time control reaches
## here this run holds nothing -- and deleting `$lock_file` unconditionally at
## this point would destroy ANOTHER run's publish lock, which is a new defect
## wearing the old line's clothes.
##
## ⚠ A RUN THAT DIES MID-PUBLISH STILL LEAVES THE LOCK BEHIND, ON PURPOSE. There
## is no trap handler here and there should not be one: the next run breaks a
## lock on EVIDENCE -- the owner pid is gone, or its cmdline is no longer the
## script that took it -- never on hope and never on a timer alone. A crashed run
## therefore costs the next one a printed NOTE, not a wedged tree.
