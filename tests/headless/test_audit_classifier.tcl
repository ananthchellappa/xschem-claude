# RED-first regression for the AUDIT CLASSIFIER itself (issue 0350).
#
# tests/headless/full_audit.sh scores every test PASS / FAIL / CRASH / TIMEOUT / SKIP by
# pattern-matching the test's merged stdout+stderr blob. `is_skip()` (full_audit.sh:116-117)
# is three UNANCHORED bash substring tests over that whole blob, and it is evaluated BEFORE
# `is_pass` (:199 vs :201). So the token "RESULT: SKIP" / "skipped: no X" /
# "SKIP: no X connection" appearing ANYWHERE -- including in the middle of a line that
# `proc check` echoes mid-run, e.g.
#
#     ok:   keyboard/ctx-menu copy (skipped: no X)  (no display)
#
# -- reclassifies the ENTIRE test as SKIP. SKIP increments only SKIP (:200), the exit gate is
# FAIL+CRASH>0 (:243) and AUDIT_MIN_PASS defaults to 0 (:254), so such a test is STRUCTURALLY
# INCAPABLE of failing the audit. Four tests are hit today -- test_save_reload_copy_selflog,
# test_descend_goback_selflog, test_delete_cut_selflog, test_key_make_sch_from_sel_log
# (6 call sites) -- and their 59 currently-green checks are discarded wholesale, as they would
# be if they turned red. Measured with a throwaway probe: a test printing FAIL and exiting 1
# was scored SKIP and the audit exited 0.
#
# THE CONTRACT THIS FILE LOCKS
#   1. A skip banner counts only at the START OF A LINE. Anywhere else (a check name, a
#      diagnostic) it is ordinary text.  -> is_skip must become line-anchored.
#   2. A FAIL line beats a skip banner.  -> a second, independent has_failure() guard.
#   3. is_skip stays AHEAD of is_pass. test_grid_toggle_sel_gc.tcl:35 prints
#      "SKIP: no X connection (has_x=0); ..." followed by "OVERALL: ok" and NO RESULT line;
#      reordering, or adopting run_suites.sh:105's "last ^RESULT line wins", turns that
#      measured must-stay-SKIP into a hollow PASS.
#   4. TIMEOUT and CRASH keep out-ranking skip (full_audit.sh:192-198, review wf_bfc3c5e4).
#
# HOW THE HARNESS IS EXERCISED
#   full_audit.sh is sourced with AUDIT_LIB_ONLY=1, which must make it define its predicates
#   and the `classify NAME OUT EC` verb and return WITHOUT running an audit. Each case then
#   calls one predicate / classify on a fixture blob and reads back a VERDICT= word.
#   XSCHEM=/bin/true satisfies the binary check at :27-30 (the guard sits below it), and
#   DISPLAY is unset so the GUI gate fails open and no control panel is raised.
#
#   RED BEFORE THE IMPLEMENTATION: neither AUDIT_LIB_ONLY nor classify() nor has_failure()
#   exists, so sourcing runs the audit proper, which exits before the verdict is echoed and
#   every case reports <no-verdict>.
#
# AUTHORING CONSTRAINT: the fixture blobs contain the very tokens under test. They live in
# Tcl variables and are NEVER echoed at column 0 -- printing one would classify THIS test as
# SKIP and hide its own failures. `check` squashes anything it reports onto one line.
#
# The same constraint applies to CHECK NAMES, and not only for is_skip: the CRASH arm
# (full_audit.sh:194) and is_pass (:106) are unanchored substring tests too, so a check name
# is a live wire in three directions. MEASURED on this very file during authoring:
#   * a name containing the literal "FATAL: signal"  -> whole suite scored CRASH
#   * a name containing the literal "OVERALL: ok"    -> is_pass matches, so once is_skip is
#     anchored this FAILING suite would be scored a hollow PASS
# Both names were reworded (C13b, C11a). That the CRASH and is_pass arms carry the identical
# defect is a SEPARATE finding from issue 0350, measured and deliberately NOT fixed here --
# anchoring them changes the classification of tests beyond this item's blast radius.
# C14 keeps ONE token deliberately, as the canary; every other name dodges. The dodge tax
# this file pays in its own comments is the same tax ~20 shipped tests already pay.
#
# C14 is a deliberate LIVE CANARY: one check whose NAME carries "skipped: no X", so this
# file's own output reproduces the defect's trigger. Post-fix it must still be scored PASS.
#
# Pure headless (no X needed). Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_audit_classifier.tcl
# Prints "RESULT: ALL PASS" / "OVERALL: ok" on success.

set fail 0; set npass 0

# One-line-ify anything reported, so a fixture blob can never reach column 0. (A raw
# "RESULT: SKIP" line echoed by a failure message would make full_audit skip this test --
# the exact bug under repair.)
proc flat {s} {
  set s [string map [list \n " | " \r " " \t " "] $s]
  if {[string length $s] > 200} { set s "[string range $s 0 199]..." }
  return $s
}
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {[flat $got]} (exp {[flat $exp]}) : FAIL"; incr fail }
}

set repo [file normalize [file join [file dirname [info script]] .. ..]]
set FA   [file join $repo tests headless full_audit.sh]
set CI   [file join $repo .github workflows ci.yaml]

# ---------------------------------------------------------------------------
# The harness driver.
#
# The sourced script's positional parameters are deliberately left as (FA mode blob name ec):
# should the AUDIT_LIB_ONLY guard be missing, full_audit reads them as a test SELECTION, finds
# no such .tcl files, and exits after five MISSING lines -- so a broken/absent guard can never
# launch a recursive audit. Output of the source itself is discarded for the same reason.
# ---------------------------------------------------------------------------
set SNIPPET {
AUDIT_LIB_ONLY=1
. "$1" >/dev/null 2>&1 || exit 91
case "$2" in
  is_skip)     if is_skip "$3"; then echo VERDICT=YES; else echo VERDICT=NO; fi ;;
  has_failure) if has_failure "$3"; then echo VERDICT=YES; else echo VERDICT=NO; fi ;;
  classify)    echo "VERDICT=$(classify "$4" "$3" "$5")" ;;
  *)           echo VERDICT=BADMODE ;;
esac
}

proc audit_lib {mode blob {name probe} {ec 0}} {
  global FA SNIPPET
  set out ""
  catch {exec env -u DISPLAY XSCHEM=/bin/true timeout 20 \
              bash -c $SNIPPET _ $FA $mode $blob $name $ec 2>@1} out
  if {[regexp {VERDICT=([A-Za-z_]+)} $out -> w]} { return $w }
  return "<no-verdict: [flat $out]>"
}
proc is_skip     {blob}          { return [audit_lib is_skip $blob] }
proc has_failure {blob}          { return [audit_lib has_failure $blob] }
proc classify    {blob name ec}  { return [audit_lib classify $blob $name $ec] }

# ---------------------------------------------------------------------------
# Fixture blobs. Every one is a verbatim shape measured in this tree, prefixed with the
# xschem startup preamble that full_audit really captures.
# ---------------------------------------------------------------------------
set PRE "Using run time directory XSCHEM_SHAREDIR = /repo/src\nSourcing /repo/src/xschemrc init file"

# 84 tests early-out in exactly this shape.
set B_SELFSKIP "$PRE\nRESULT: SKIP (no X)"

# test_grid_toggle_sel_gc.tcl:35 -- a skip banner that is NOT a RESULT line, next to OVERALL: ok.
set B_GRID "$PRE\nSKIP: no X connection (has_x=0); run under DISPLAY with --pipe\nOVERALL: ok"

# The legacy self-skip banner. Extinct as an emitted string; a resurrected test must not
# score a hollow PASS.
set B_LEGACY "$PRE\nRESULT: ALL PASS (0 checks, skipped: no X)"

# ISSUE 0350 PROPER: a fully passing run whose check NAME carries the token
# (test_save_reload_copy_selflog.tcl:139/205/280 shape).
set B_INNAME "$PRE\nok:   ctx-menu copy  (ok)\nok:   keyboard save (skipped: no X)  (no display)\nok:   reload keeps buffer  (ok)\nRESULT: ALL PASS (25 checks)"

# The token mid-line in a diagnostic rather than a check name -- locks the anchor itself.
set B_DIAG "$PRE\nnote: a RESULT: SKIP here must not count\nRESULT: ALL PASS (4 checks)"

# The Before agent's throwaway probe, made permanent: in-name token AND real failures.
set B_PROBE "$PRE\nok:   keyboard path (skipped: no X)  (no display)\nFAIL: deliberate failure for audit-probe -> {3} (exp {1}) : FAIL\nRESULT: 1 FAILURE(S) (3 checks)"

# A GENUINE wholesale skip banner alongside a real FAIL line: the failure must win.
set B_SKIPFAIL "$PRE\nRESULT: SKIP (no X)\nFAIL: teardown left the buffer MODIFIED -> {1} (exp {0}) : FAIL"

# run_regression sentinels, the two arms of full_audit.sh:106.
set B_OK    "$PRE\nok:   something  (ok)\nOVERALL: ok"
set B_NOTOK "$PRE\nok:   something  (ok)\nOVERALL: notok"

# fail/failure as ORDINARY WORDS inside passing check names -- has_failure must not bite.
set B_WORDS "$PRE\nok:   undo after a failed paste  (ok)\nok:   the failure counter stayed 0  (ok)\nRESULT: ALL PASS (2 checks)"

# A test that printed its skip banner and then died (review wf_bfc3c5e4).
set B_CRASH "$PRE\nRESULT: SKIP (no X)\nFATAL: signal 11 caught, exiting"

# A per-NAME is_pass arm that does NOT self-guard, next to a wholesale skip banner.
# full_audit.sh's `*)` arm (:106-107) and the two banner arms (:105) call `! is_skip`
# THEMSELVES, so for those the chain order is unobservable; the seven name-specific arms
# (test_palette :94, test_ciw_autocomplete :95, test_ciw_puts_capture :96,
# test_lib_new_discovered_defs :97, test_nogui :98, test_readonly_guard :99,
# test_readonly_action_dispatch :100) do not. They are the ONLY place where "is_skip runs
# before is_pass" is load-bearing -- the hollow-green mode where an X server dies after a
# test emitted its sentinel but before it finished.
set B_SENTINEL_SKIP "$PRE\nNOGUI_TEST_PASS\nRESULT: SKIP (no X)"

# ---------------------------------------------------------------------------
# A. is_skip() -- the predicate. What must STAY a skip, and what must stop being one.
# ---------------------------------------------------------------------------
check "C1 is_skip: canonical `RESULT: SKIP (no X)` self-skip"        [is_skip $B_SELFSKIP] YES
check "C2 is_skip: grid-toggle `SKIP: no X connection` + OVERALL:ok" [is_skip $B_GRID]     YES
check "C3 is_skip: legacy `ALL PASS (0 checks, skipped: no X)`"      [is_skip $B_LEGACY]   YES
check "C4 is_skip: token inside a check NAME is NOT a skip (0350)"   [is_skip $B_INNAME]   NO
check "C5 is_skip: token mid-line in a diagnostic is NOT a skip"     [is_skip $B_DIAG]     NO

# ---------------------------------------------------------------------------
# B. has_failure() -- the independent second guard.
# ---------------------------------------------------------------------------
check "C12 has_failure: fail/failure as words in check names -> no" [has_failure $B_WORDS] NO

# ---------------------------------------------------------------------------
# C. classify() -- the whole chain, and its ORDERING.
# ---------------------------------------------------------------------------
check "C6 classify: in-name token + ALL PASS -> PASS (0350)"        [classify $B_INNAME   c6  0]   PASS
check "C7 classify: in-name token + FAIL lines -> FAIL"             [classify $B_PROBE    c7  1]   FAIL
check "C8 classify: real skip banner + a FAIL line -> FAIL"         [classify $B_SKIPFAIL c8  1]   FAIL
check "C9 classify: lone self-skip banner -> SKIP"                  [classify $B_SELFSKIP c9  0]   SKIP
check "C10a classify: grid-toggle shape -> SKIP, not a hollow PASS" [classify $B_GRID     c10 0]   SKIP
check "C10b classify: skip outranks a non-self-guarding pass arm"   [classify $B_SENTINEL_SKIP test_nogui 0] SKIP
check "C11a classify: the run_regression ok-sentinel alone -> PASS" [classify $B_OK       c11 0]   PASS
check "C11b classify: the notok sentinel -> FAIL"                   [classify $B_NOTOK    c11 1]   FAIL
check "C13a classify: exit code 124 -> TIMEOUT"                     [classify $B_SELFSKIP c13 124] TIMEOUT
check "C13b classify: a fatal-signal line outranks a skip banner"   [classify $B_CRASH    c13 139] CRASH

# ---------------------------------------------------------------------------
# D. The live canary (issue 0350). This check's NAME carries the token, so this file's own
#    output reproduces the trigger. If the predicate ever reverts to an unanchored substring
#    test, full_audit scores test_audit_classifier SKIP -- and the CI headless gate's
#    AUDIT_MIN_PASS floor (== the number of listed suites) turns red because of it.
# ---------------------------------------------------------------------------
check "C14 canary: keyboard path (skipped: no X)" 1 1

# ---------------------------------------------------------------------------
# E. The CI hard gate (issue 0351). ci.yaml's cheap headless step must name every suite the
#    driver treats as a tier, and must carry a pass floor equal to that count -- a floor is
#    what makes "all-skip" fail instead of exiting 0 with zero coverage.
#    Measured: all of these pass with DISPLAY unset, so they belong in the deterministic
#    step, not behind xvfb.
# ---------------------------------------------------------------------------
set GATED {
  test_sweep_diff test_nogui
  test_shape_draw_gate test_paste_modify_flag_0244 test_add_wire_label
  test_placement_wire_gate test_label_ride test_placement_preview_doors
  test_label_strand_oracle test_sch_add_pin test_wire_split
  test_crossview_paste test_instance_update
  test_audit_classifier test_descend_inert_class
}

# The body of a `- name: <step>` block. Stops at the next step-level `- name:` AND at the
# next step-level `#` comment, because in this file a step's explanatory comments sit at
# 4-space indent ABOVE the step they describe -- swallowing them would let a name mentioned
# in the *next* step's prose satisfy this gate's assertion (a false green). Comments inside
# a `run: |` body are indented 6+ spaces and are kept.
proc ci_step {text want} {
  set keep 0; set out {}
  foreach ln [split $text \n] {
    if {[regexp {^ {4}- name:[ ]*(.*)$} $ln -> nm]} {
      if {$keep} { break }
      if {[string match -nocase "*$want*" [string trim $nm]]} { set keep 1 }
      continue
    }
    if {$keep && [regexp {^ {4}#} $ln]} { break }
    if {$keep} { lappend out $ln }
  }
  return [join $out \n]
}

set ci ""
if {[catch {set fh [open $CI r]; set ci [read $fh]; close $fh} e]} { set ci "<unreadable: $e>" }
set gate [ci_step $ci "Headless gate"]

set missing {}
foreach t $GATED {
  # built by append, not interpolation: "$t(" would parse as an array subscript
  set pat {(^|[^A-Za-z0-9_])}
  append pat $t {([^A-Za-z0-9_]|$)}
  if {![regexp $pat $gate]} { lappend missing $t }
}
check "C15a ci.yaml headless gate names every gated suite" [join $missing " "] {}

set floor -1
if {[regexp {AUDIT_MIN_PASS=([0-9]+)} $gate -> f]} { set floor $f }
check "C15b ci.yaml headless gate floor >= [llength $GATED] (got $floor)" \
      [expr {$floor >= [llength $GATED]}] 1

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
