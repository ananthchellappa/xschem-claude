#
#  File: banner_rule.tcl
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
#
# ---------------------------------------------------------------------------
# THE COMPLETION-BANNER RULE, in one place (issue 0689).
#
# Three readers decide whether a headless suite finished and reported:
#   tests/run_regression.tcl   -- sources THIS file (the only Tcl reader)
#   tests/headless/run_suites.sh  -- its own ERE, necessarily: it is /bin/sh
#   tests/headless/full_audit.sh  -- likewise
# The shell pair cannot source a Tcl file, so the rule exists in three spellings.
# tests/headless/test_audit_classifier.tcl section K locks TWO of them together BY
# VERDICT, not byte for byte: K18 extracts run_suites.sh's ERE from source and
# compares it to banner_complete fixture for fixture, and K19 does the same for
# full_audit.sh's two crash literals. Either of those may be re-spelled; neither
# may drift.
#
# ⚠ THE THIRD SPELLING IS NOT LOCKED, AND IT DOES DIVERGE. full_audit.sh's is_pass
# `*)` arm is only PREFIX-anchored (`^(RESULT: ALL PASS|OVERALL: ok)`), so it
# ACCEPTS `OVERALL: okay then` and `OVERALL: ok<TAB>junk`, which banner_complete
# and run_suites.sh both reject (measured 2026-08-25 through AUDIT_LIB_ONLY=1).
# No suite in the tree emits either shape, so the divergence is latent, not live;
# it is filed as issue 0805 rather than fixed here, because full_audit is the CI
# gate and test_audit_classifier section H locks its classification. Do not
# describe the three readers as agreeing until 0805 lands.
#
# WHY THIS FILE EXISTS AT ALL. run_regression.tcl used to carry a PRIVATE copy
# anchored at both ends -- {^OVERALL: ok$}. Suites that append a check count to
# their banner could therefore never match it, and were scored a HARNESS failure
# with every one of their own checks passing. That standing red was filed FOUR
# times (0420, 0492, 0629, 0689) and waved through as furniture each time,
# because a copied shape drifts silently and a shared one cannot. One builder for
# the Tcl side; the two shell readers are separate spellings held by K18/K19 (and,
# for full_audit's is_pass, not yet held at all -- see 0805 above).
#
# THE THREE BANNER SHAPES THE TREE ACTUALLY EMITS (swept, 2026-08-25):
#   OVERALL: ok                       131 sites
#   OVERALL: ok (N checks)              5 sites (test_pdk_launcher:119,
#                                       test_ihp_sg13g2_libmgr:195,
#                                       test_descend_inert_class:183,
#                                       test_context_menu_descend_refusal_0249:110,
#                                       test_descend_refusal_channel_0251:437)
#   OVERALL: ok  (all checks passed)    2 sites, DOUBLE space
#                                       (test_dblclick_connected_grow:334,
#                                       test_select_same_net_by_label:259)
# Only two of those seven non-bare emitters are in run_regression's hcases list
# today, which is why there were exactly two false reds and not seven; the other
# five were latent, and adding any of them to hcases would have produced an
# instant new one.
# ---------------------------------------------------------------------------

# Did the suite FINISH AND REPORT?
#
# WHOLE LINE, never a substring: the banner text quoted inside a check's own
# message must not forge a completion. An optional parenthesised trailer is
# tolerated, with any run of spaces/tabs before it. Every failure spelling
# ("notok", "OVERALL: FAIL", "OVERALL: N FAILED") falls through to 0.
#
# [ \t] and not [[:space:]]: Tcl's -line mode still lets a bracket class that
# contains \n match across the line boundary, which would let a banner on one
# line pick up the start of the next. The shell side may keep [[:space:]]
# because grep is line-oriented; K18 asserts the two agree regardless.
proc banner_complete {body} {
  return [regexp -line {^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$} $body]
}

# Did the suite DIE, whatever it printed before dying?
#
# The two literals are full_audit.sh's own crash arm (full_audit.sh:315-316),
# column-0 anchored so a log that merely QUOTES them mid-line is not a death.
#
# This predicate is why relaxing the completion anchor is safe. Measured during
# issue 0689: `xschem --nogui --pipe` exits 0 on an uncaught mid-script Tcl
# error, so a suite that printed a bare banner and THEN died was scored a silent
# PASS -- for all 131 bare-banner sites. (summarize_all's grep never sees it
# either: the death line neither ends in FAIL nor starts with FATAL.) The
# counted variant was caught only BY ACCIDENT, because the count broke the
# anchor. Relax the anchor alone and that accident is lost: a quieter harness,
# not a better one. Relax it WITH this predicate and all three shapes are
# handled for the first time.
#
# DELIBERATELY STRICTER THAN full_audit.sh, which guards the same Tcl_AppInit
# literal with `&& ! is_pass` and therefore still scores pass-banner-then-death
# as PASS. Filed as issue 0802 rather than fixed here: changing full_audit's
# classification moves test_audit_classifier section H, which is in the CI gate
# list, and that is a bigger blast radius than a harness-trust fix warrants.
proc banner_died {body} {
  return [regexp -line {^(FATAL: signal|Tcl_AppInit\(\) error)} $body]
}

# The composite verdict for one headless case: 1 = count it as a failure.
#
# EXIT 0 AND a completion banner AND no death marker. The child-code arm comes
# first and is untouched by 0689 -- it is what catches a binary that never
# launched (a non-CHILDSTATUS -errorcode yields childcode 1 and an empty log, so
# both halves fire). The `couldn't execute "xschem"` / exit-127 markers of issue
# 0016 Part 4 are NOT in the death set: they belong to the golden cases' /bin/sh
# jobs and to run_regression's xschemtest guard, neither of which this predicate
# is reached from. Folding them in "for symmetry" would blur that distinction.
proc regression_case_failed {childcode body} {
  if {$childcode != 0} { return 1 }
  if {![banner_complete $body]} { return 1 }
  if {[banner_died $body]} { return 1 }
  return 0
}
