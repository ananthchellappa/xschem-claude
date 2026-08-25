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
# ---------------------------------------------------------------------------------------
# EXTENDED FOR ISSUE 0354 (+0352/0353/0355/0356). The "SEPARATE finding" flagged above was
# filed as 0354 and measured again here: 0350 anchored ONE of the five predicates, and the
# other four still compare the whole blob with unanchored bash `==` globs. Sections F-H lock
# the same contract on them --
#   F  is_pass          a pass banner counts only at the START OF A LINE   (0354 H1)
#   G  has_failure      widened to the 5 failure-banner shapes the tree emits (0354 H2),
#                       still column-0 only (0350 D2)
#   H  is_skip legacy alternative (0354 H3) and BOTH crash arms -- the second, the
#                       unanchored `Tcl_AppInit() error` test, is 0354 H4, measured by this
#                       item and absent from the original filing
# -- and sections I/J lock the two arms that are not classification at all:
#   I  a working-tree DELTA next to the directory glob, because scratch_snapshot is
#      structurally blind to a leaked FILE (0353), a differently-named DIR (0352) and a
#      DELETED file (0356). Report-only: it must never feed the `rm -rf` at full_audit.sh:309.
#   J  issue 0355, both halves: the suite that hangs forever under any display.
# ---------------------------------------------------------------------------------------
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
set PWG  [file join $repo tests headless test_placement_wire_gate.tcl]

# A private throw-away tree for the working-tree-leak arm (F/I below): C37-C40 need a
# REAL git repo to snapshot, and it must not be this one.
source [file join [file dirname [info script]] scratch.tcl]
set scratch [test_scratch audclass]

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
  is_pass)     if is_pass "$4" "$3" "$5"; then echo VERDICT=YES; else echo VERDICT=NO; fi ;;
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
proc is_pass     {blob name ec}  { return [audit_lib is_pass $blob $name $ec] }
proc classify    {blob name ec}  { return [audit_lib classify $blob $name $ec] }

# ---------------------------------------------------------------------------
# The working-tree-leak probe (C37-C40, issues 0352/0353/0356).
#
# scratch_snapshot() only ever globs DIRECTORIES named `_*_[0-9]*` in four fixed parents, so
# a leaked FILE (untitled-NN.sch) and a directory with any other name (undo_link_child/) are
# structurally invisible to it -- and so is a file the run DELETED. The second arm must be a
# working-tree delta, not another name guess.
#
# One bash run builds a REAL but synthetic git repo (never this one), snapshots it, mutates it
# the way the two leaking suites mutate the repo root, snapshots again, and prints the two
# directions plus what the directory arm saw. Both snapshot verbs are called with the root as
# $1 so the probe cannot touch the developer's tree.
#
# RED BEFORE THE IMPLEMENTATION: tree_delta_snapshot does not exist, so both snapshots are
# empty and every delta line is missing. `TREEPROBE_DONE` distinguishes that honest red from a
# broken harness (git missing, mkdir refused) -- tp_has reports the raw blob in that case.
# ---------------------------------------------------------------------------
set TREE_SNIPPET {
AUDIT_LIB_ONLY=1
. "$1" >/dev/null 2>&1 || exit 91
root="$2"
rm -rf "$root" || exit 92
mkdir -p "$root" || exit 92
git -C "$root" init -q >/dev/null 2>&1 || exit 93
# The synthetic tree must carry THIS repo's ignore rules, or the probe measures a
# tree the arm never inspects. `git status` honours .gitignore, and .gitignore:55/56
# hide `*~.sch` / `*~.sym` -- so the autosave-backup leaks are invisible to the arm.
# That blind spot is real (issue 0356); C39b/C39c lock it so nobody re-reads the arm
# as total coverage.
cp "$3" "$root/.gitignore" 2>/dev/null || exit 94
: > "$root/vanishes.txt"
: > "$root/backup~.sch"
tb=$(tree_delta_snapshot "$root" 2>/dev/null)
sb=$(scratch_snapshot "$root" 2>/dev/null)
: > "$root/untitled-1.sch"
: > "$root/leaked~.sch"
mkdir -p "$root/undo_link_child"
: > "$root/undo_link_child/drive.tcl"
rm -f "$root/vanishes.txt"
rm -f "$root/backup~.sch"
ta=$(tree_delta_snapshot "$root" 2>/dev/null)
sa=$(scratch_snapshot "$root" 2>/dev/null)
comm -13 <(printf '%s\n' "$tb") <(printf '%s\n' "$ta") | sed 's/^/TREEADD /'
comm -23 <(printf '%s\n' "$tb") <(printf '%s\n' "$ta") | sed 's/^/TREEDEL /'
comm -13 <(printf '%s\n' "$sb") <(printf '%s\n' "$sa") | sed 's/^/SCRATCHADD /'
echo TREEPROBE_DONE
}

set TP ""
catch {exec env -u DISPLAY XSCHEM=/bin/true timeout 30 \
            bash -c $TREE_SNIPPET _ $FA [file join $scratch gittree] \
            [file join $repo .gitignore] 2>@1} TP

proc tp_has {re} {
  global TP
  if {![string match "*TREEPROBE_DONE*" $TP]} { return "probe-did-not-run: [flat $TP]" }
  return [regexp -line -- $re $TP]
}

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
# ISSUE 0354 fixtures. 0350 anchored exactly ONE of the five predicates; the other four still
# compare the whole merged stdout+stderr blob with unanchored bash `==` globs, so a token in a
# check NAME still decides a whole suite's verdict -- now in the is_pass and CRASH directions
# instead of the is_skip one. Each blob below is the measured shape from the issue.
# ---------------------------------------------------------------------------

# H1: the hole that props up the CI floor. A run with three real failure lines and exit 1,
# whose only sin is a check NAME quoting the run_regression sentinel -> is_pass says yes.
set B_PASSNAME "$PRE\nok:   replay log agrees with the child run  (OVERALL: ok)\nFAIL: parent assertion -> {1} (exp {0}) : FAIL\nRESULT: 1 FAILED (1 passed)\nOVERALL: notok"

# Anti-overshoot for H1: the two real column-0 banner shapes the `*)` arm exists to accept.
set B_ALLPASS "$PRE\nok:   something  (ok)\nRESULT: ALL PASS (25 checks)"
set B_OKVAR   "$PRE\nok:   something  (ok)\nOVERALL: ok  (all checks passed)"

# The third banner shape (test_cadence_descend_newwin_ro.tcl:71, test_hi_descend.tcl:163). It is
# prefixed BY CONSTRUCTION, so it is the one arm that needs anchoring at BOTH ends.
set B_THIRD     "$PRE\nok:   descended into the new window  (ok)\ncadence_descend_newwin_ro headless: all checks passed"
set B_THIRDNAME "$PRE\nok:   sub-window headless: all checks passed  (ok)\nFAIL: the highlight was lost -> {0} (exp {1}) : FAIL\nhi_descend headless: 1 FAILURE(S)"

# H2: the five failure-banner shapes the tree really emits and has_failure cannot see.
#   RESULT: <n> FAIL           19 sites, incl. test_cadence_stretch_move.tcl:170
#   RESULT: FAIL (...)          6 sites (run_nogui.sh, test_readonly_*.sh)
#   OVERALL: fail               4 sites (lowercase)
#   OVERALL: <n> FAILED, ...    test_descend_inert_class.tcl:151 -- a CI hard-gated suite
#   RESULT: FAILED              test_coordlog_precision.tcl:62
set B_HF_RESFAIL  "$PRE\nRESULT: 2 FAIL"
set B_HF_RESPAREN "$PRE\nRESULT: FAIL (2 ok, 3 fail)"
set B_HF_LOWER    "$PRE\nOVERALL: fail"
set B_HF_COUNTED  "$PRE\nOVERALL: 3 FAILED, 2 passed"
set B_HF_BARE     "$PRE\nRESULT: FAILED"
# An INDENTED failure line: a suite echoing a child run's output. Must NOT bite -- the column-0
# contract is ratified (0350 D2) and widening it would redden the xvfb gate for someone else's
# failure.
set B_HF_INDENT   "$PRE\n  FAIL: child run assertion -> {1} (exp {0}) : FAIL"
# H2 proper: a genuine wholesale skip banner next to failure banners has_failure misses.
set B_SKIPFAIL2   "$PRE\nRESULT: SKIP (GUI legs need a usable display)\nnot ok: the headless leg actually failed\nRESULT: 2 FAIL\nOVERALL: fail"

# H3: is_skip's third alternative anchors `RESULT:`, not the token, so a fully GREEN suite that
# merely mentions the note on its RESULT line is scored SKIP.
set B_NOTEONRESULT "$PRE\nok:   headless legs  (ok)\nRESULT: ALL PASS (20 checks; 3 keyboard legs skipped: no X)\nOVERALL: ok"

# The two CRASH arms, both unanchored. The first turns a green suite into a CRASH; the second
# (issue 0354 H4, found by this item's scout and NOT named in the original filing) turns a
# genuinely FAILING suite into a CRASH.
set B_FATALNAME   "$PRE\nok:   the handler survives a FATAL: signal  (ok)\nRESULT: ALL PASS (5 checks)\nOVERALL: ok"
set B_APPINITNAME "$PRE\nok:   recover from a Tcl_AppInit() error  (ok)\nFAIL: the recovery left the buffer MODIFIED -> {1} (exp {0}) : FAIL\nRESULT: 3 FAILED (2 passed)\nOVERALL: notok"
set B_APPINITREAL "$PRE\nTcl_AppInit() error: can't find package Tk"

# The name-specific sentinel arms carry the identical defect (test_nogui is a CI hard gate).
set B_SENTNAME "$PRE\nok:   the sentinel NOGUI_TEST_PASS is printed exactly once  (ok)\nFAIL: --nogui still opened a toplevel -> {1} (exp {0}) : FAIL\nRESULT: 1 FAILED (1 passed)"
set B_SENTREAL "$PRE\nNOGUI_TEST_PASS"

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

# ---------------------------------------------------------------------------
# F. is_pass() -- the SAME defect 0350 fixed in is_skip, one function down (issue 0354 H1).
#    Every arm must assert the SHAPE it names. This is the only direction that can move a
#    suite PASS -> FAIL, i.e. redden the CI floor, so each positive row is paired with an
#    anti-overshoot row that must stay green in both directions.
# ---------------------------------------------------------------------------
check "C16 is_pass: the ok-sentinel quoted mid-line is not a pass" [is_pass $B_PASSNAME probe 1] NO
check "C17 classify: that same blob at ec=1 -> FAIL, not a hollow pass" \
      [classify $B_PASSNAME c17 1] FAIL
check "C18 is_pass: a real column-0 all-pass banner still passes"  [is_pass $B_ALLPASS  probe 0] YES
check "C19 is_pass: the annotated ok-sentinel variant still passes" [is_pass $B_OKVAR   probe 0] YES
check "C20 is_pass: the prefixed third banner still passes" \
      [is_pass $B_THIRD test_cadence_descend_newwin_ro 0] YES
check "C21 is_pass: that banner quoted in a check name is not a pass" \
      [is_pass $B_THIRDNAME test_hi_descend 1] NO
check "C35 classify: the nogui sentinel quoted in a name -> FAIL" \
      [classify $B_SENTNAME test_nogui 1] FAIL
check "C36 classify: the real column-0 nogui sentinel -> PASS" \
      [classify $B_SENTREAL test_nogui 0] PASS

# ---------------------------------------------------------------------------
# G. has_failure() -- widened to the banner shapes the tree actually emits (issue 0354 H2).
#    Its ONLY consumer is classify's skip arm, so widening can only move a suite SKIP -> FAIL.
#    The column-0 requirement stays (0350 D2): an indented echo of someone else's failure must
#    not redden this suite.
# ---------------------------------------------------------------------------
check "C22 has_failure: counted `RESULT: n FAIL` (no -ED) -> yes" [has_failure $B_HF_RESFAIL]  YES
check "C23 has_failure: the parenthesised RESULT failure banner"  [has_failure $B_HF_RESPAREN] YES
check "C24 has_failure: the lowercase OVERALL failure banner"     [has_failure $B_HF_LOWER]    YES
check "C25 has_failure: the counted OVERALL failure banner"       [has_failure $B_HF_COUNTED]  YES
check "C26 has_failure: the bare RESULT failure banner"           [has_failure $B_HF_BARE]     YES
check "C27 has_failure: an INDENTED failure line -> no (0350 D2)" [has_failure $B_HF_INDENT]   NO
check "C28 has_failure: a lone self-skip banner is not a failure" [has_failure $B_SELFSKIP]    NO
check "C29 classify: a skip banner + those banners -> FAIL"       [classify $B_SKIPFAIL2 c29 1] FAIL

# ---------------------------------------------------------------------------
# H. The remaining unanchored arms: is_skip's legacy alternative (0354 H3) and BOTH crash
#    predicates (the second is H4 -- measured by this item, absent from the original filing).
# ---------------------------------------------------------------------------
check "C30 is_skip: the note quoted on a green RESULT line -> no" [is_skip $B_NOTEONRESULT] NO
check "C31 classify: that green suite -> PASS, not a skip"        [classify $B_NOTEONRESULT c31 0] PASS
check "C32 classify: a fatal-signal token in a check name -> PASS" [classify $B_FATALNAME   c32 0] PASS
check "C33 classify: an appinit token in a check name -> FAIL"     [classify $B_APPINITNAME c33 1] FAIL
check "C34 classify: a real column-0 appinit error -> CRASH"       [classify $B_APPINITREAL c34 1] CRASH

# ---------------------------------------------------------------------------
# I. The working-tree leak arm (issues 0352, 0353, 0356). Report-only by construction: it must
#    see what the directory glob cannot, and it must never feed a removal or an exit path --
#    full_audit.sh:309 `rm -rf`s whatever the scratch snapshot reports, and files shaped like
#    `untitled-NN.sch` are shaped exactly like unsaved user work.
# ---------------------------------------------------------------------------
check "C37 tree delta sees a leaked .sch FILE (0353)" \
      [tp_has {^TREEADD .*untitled-1\.sch$}] 1
check "C38 tree delta sees a leaked non-scratch DIR (0352)" \
      [tp_has {^TREEADD .*undo_link_child/drive\.tcl$}] 1
check "C39a tree delta sees a NON-IGNORED file the run DELETED" \
      [tp_has {^TREEDEL .*vanishes\.txt$}] 1
# C39b/C39c lock the arm's MEASURED LIMIT, not a capability. `git status` honours
# .gitignore, and .gitignore:55/56 hide `*~.sch` / `*~.sym`, so autosave-backup
# leaks are invisible in BOTH directions -- which is 100% of issue 0356's only
# measured instance (tests/untitled-16~.sch) and the backup half of 0353. These two
# rows exist so the gap cannot be silently re-read as coverage; widening the arm is
# an open decision recorded in 0356, not something this item settled.
check "C39b tree delta CANNOT see a leaked *~.sch -- .gitignore:55 (0356, still open)" \
      [tp_has {^TREEADD .*leaked~\.sch$}] 0
check "C39c tree delta CANNOT see a DELETED *~.sch -- 0356's own filed shape" \
      [tp_has {^TREEDEL .*backup~\.sch$}] 0
check "C40 the directory arm sees neither -- that is its documented blind spot" \
      [list [tp_has {^SCRATCHADD .*untitled-1\.sch}] [tp_has {^SCRATCHADD .*undo_link_child}]] {0 0}

# The report-only contract, asserted on the source: no line that carries the tree-delta arm may
# also carry a removal or an exit. Comment lines are exempt (they describe the arm).
set fa ""
if {[catch {set fh [open $FA r]; set fa [read $fh]; close $fh} e]} { set fa "<unreadable: $e>" }
set td_lines {}
foreach ln [split $fa \n] {
  if {[regexp {^[ \t]*#} $ln]} continue
  if {[regexp {tree_delta_snapshot|TREE_BEFORE|TREE_LEAKED|TREEADD|TREEDEL} $ln]} { lappend td_lines $ln }
}
set td_danger {}
foreach ln $td_lines {
  if {[regexp {(^|[^A-Za-z_])(rm|exit)([^A-Za-z_]|$)} $ln]} { lappend td_danger [string trim $ln] }
}
check "C41 the tree-delta arm exists and feeds no removal / no exit" \
      [list [expr {[llength $td_lines] > 0}] [join $td_danger " ; "]] {1 {}}

# ---------------------------------------------------------------------------
# J. Issue 0355, both halves. test_placement_wire_gate is a driver tier AND a CI hard-gated
#    suite; with any display it blocks forever at its place_text row (measured at 120s under
#    WSLg and 300s under xvfb), because the modal it raises for real has nobody to dismiss it.
#    Half A puts it in the harness's --nogui list; half B makes the suite itself refuse to run
#    under a display, so a human or agent invoking it by hand gets an honest instant skip
#    instead of a hang. A behavioural check would have to run it under X, which is exactly what
#    must not happen -- so both halves are asserted on the source.
# ---------------------------------------------------------------------------
set ngt ""
regexp {nogui_tests="([^"]*)"} $fa -> ngt
set pat {(^|[^A-Za-z0-9_])test_placement_wire_gate([^A-Za-z0-9_]|$)}
check "C42 full_audit runs test_placement_wire_gate with --nogui" [regexp $pat $ngt] 1

set pwg ""
if {[catch {set fh [open $PWG r]; set pwg [read $fh]; close $fh} e]} { set pwg "<unreadable: $e>" }
set i_guard -1; set i_skip -1; set i_chk -1; set i 0
foreach ln [split $pwg \n] {
  if {$i_guard < 0 && [regexp {winfo exists \.} $ln]}   { set i_guard $i }
  if {$i_skip  < 0 && [regexp "puts \"RESULT: SKIP" $ln]} { set i_skip $i }
  if {$i_chk   < 0 && [regexp {^check } $ln]}           { set i_chk $i }
  incr i
}
check "C43 test_placement_wire_gate self-guards on a display before its first check" \
      [list [expr {$i_guard >= 0}] [expr {$i_skip >= 0}] \
            [expr {$i_chk >= 0 && $i_guard >= 0 && $i_guard < $i_chk}] \
            [expr {$i_chk >= 0 && $i_skip  >= 0 && $i_skip  < $i_chk}]] {1 1 1 1}

# ---------------------------------------------------------------------------
# J. run_suites.sh's PRIVATE COPY of the skip predicate (merge 5 section 5.5)
#
# run_suites.sh cannot call is_skip -- it scores its own runs -- so it carries a second
# copy of the regexp, and the merge shipped the two out of sync: full_audit's was
# line-anchored by 0354 H1 while run_suites.sh's was still the unanchored
# 'RESULT: SKIP|skipped: no X|SKIP: no X connection'. Unanchored, "skipped: no X" matches
# inside a CHECK NAME (test_save_reload_copy_selflog.tcl:139,205,280), so four suites that
# ran every check and exited 0 were scored SKIP by the driver CLAUDE.md calls preferred and
# PASS by full_audit. Asserted on the SOURCE of both files, because reproducing it
# behaviourally needs a full suite run.
#
# The assertion is EQUALITY, not a spelling: whichever way the predicate is next revised,
# both copies must move together or this check reddens.
# ---------------------------------------------------------------------------
set RS [file join $repo tests headless run_suites.sh]
set rs ""
if {[catch {set fh [open $RS r]; set rs [read $fh]; close $fh} e]} { set rs "<unreadable: $e>" }
set fa_re ""; set rs_re ""
regexp {line_has '(\^\(RESULT: SKIP[^']*)' "\$1"} $fa -> fa_re
regexp {grep -qE '(\^\(RESULT: SKIP[^']*)'} $rs -> rs_re
check "C44 run_suites.sh's skip regexp is line-anchored and identical to is_skip's" \
      [list [expr {$fa_re ne ""}] [expr {$rs_re ne ""}] [expr {$fa_re eq $rs_re}]] {1 1 1}


# ---------------------------------------------------------------------------
# K. THE THIRD READER'S BANNER RULE (issues 0689 + 0802).
#
# tests/run_regression.tcl is the one reader of the three that carries a PRIVATE
# copy of the completion-banner shape, and its copy is anchored at BOTH ends
# (:117). Two shipped suites end their run with a check COUNT appended to the
# banner, so the copy can never match them: both are scored a HARNESS failure
# while every one of their own checks passed. That standing red has been filed
# four times (0420, 0492, 0629, 0689) and waved through as furniture every time.
#
# THE CONTRACT THIS SECTION LOCKS, in tests/banner_rule.tcl:
#   1. banner_complete  -- the banner counts WHOLE-LINE, an optional
#      parenthesised trailer is tolerated, and every failure spelling is
#      rejected. Same rule as run_suites.sh:155, which already ships it as an
#      ERE; K18 asserts the two agree fixture-for-fixture rather than
#      byte-for-byte, so either may be re-spelled but neither may drift.
#   2. banner_died      -- a column-0 crash marker is a death REGARDLESS of what
#      banner was printed before it. Measured during this item: a suite that
#      prints a bare banner and THEN dies exits 0 and is scored a silent PASS
#      today, for all 131 bare-banner sites. Relaxing the anchor without this
#      predicate would move the two counted suites into that same hole -- a
#      quieter harness, not a better one.
#   3. regression_case_failed -- exit 0 AND a completion banner AND no death.
#      A nonzero child code still beats any banner (0016 Part 4: the arm that
#      catches a binary that never launched is the child code, and it is not
#      touched here).
#
# DELIBERATE DIVERGENCE, FILED AS 0802: full_audit.sh:315-316 guards its
# Tcl_AppInit arm with `&& ! is_pass`, so a pass banner followed by a death is
# scored PASS there. banner_died carries no such clause. K9-K12 lock the
# stricter behaviour; the laxer one is filed, not fixed, because changing
# full_audit's classification moves section H, which is in the CI gate list.
#
# RED BEFORE THE IMPLEMENTATION: tests/banner_rule.tcl does not exist, so the
# probe reports NO_RULE_FILE for every behavioural row, and run_regression.tcl
# still carries its private copy (K17).
#
# AUTHORING CONSTRAINT (the same one this file's header states): no fixture blob
# and no check NAME below may carry the literal banner or death text at column 0
# of this suite's own stdout. Fixtures live in variables and only ever reach the
# log through `flat`; the names say "completion banner" / "death marker".
# ---------------------------------------------------------------------------
set BR [file join $repo tests banner_rule.tcl]

# Out-of-process on a bare tclsh, deliberately: run_regression.tcl is a tclsh
# script, so a banner_rule.tcl that needed anything from xschem's interpreter
# would pass an in-process probe and break the only consumer there is.
set BR_PROBE_SRC {
  if {[catch {source [lindex $argv 0]} e]} { puts "VERDICT=NO_RULE_FILE"; exit 0 }
  set mode [lindex $argv 1]
  set body [lindex $argv 2]
  set ec   [lindex $argv 3]
  set r ""
  switch -exact -- $mode {
    complete { set c [catch {banner_complete $body} r] }
    died     { set c [catch {banner_died $body} r] }
    failed   { set c [catch {regression_case_failed $ec $body} r] }
    default  { puts "VERDICT=BADMODE"; exit 0 }
  }
  if {$c} { puts "VERDICT=NO_PROC"; exit 0 }
  if {[catch {expr {$r ? "YES" : "NO"}} v]} { set v NONBOOL }
  puts "VERDICT=$v"
}
set BR_PROBE [file join $scratch banner_probe.tcl]
set f [open $BR_PROBE w]; puts $f $BR_PROBE_SRC; close $f
set TCLSH [lindex [auto_execok tclsh] 0]
if {$TCLSH eq {}} { set TCLSH tclsh }

proc banner_probe {mode body {ec 0}} {
  global BR BR_PROBE TCLSH
  set out ""
  catch {exec $TCLSH $BR_PROBE $BR $mode $body $ec 2>@1} out
  if {[regexp {VERDICT=([A-Za-z_]+)} $out -> w]} { return $w }
  return "<no-verdict: [flat $out]>"
}
proc banner_complete {body}      { return [banner_probe complete $body] }
proc banner_died     {body}      { return [banner_probe died $body] }
proc case_failed     {ec body}   { return [banner_probe failed $body $ec] }

# --- fixtures: every shape tests/headless/*.tcl actually emits ---------------
set RPRE "Using run time directory XSCHEM_SHAREDIR = /repo/src\nSourcing /repo/src/xschemrc init file"

# the bare banner: 131 emitter sites
set R_BARE   "$RPRE\nok:   something  (ok)\nOVERALL: ok"
# test_pdk_launcher.tcl:119 -- the measured false red
set R_C30    "$RPRE\nok:   something  (ok)\nOVERALL: ok (30 checks)"
# test_ihp_sg13g2_libmgr.tcl:195 once its golden catches up with the tree (0690)
set R_C67    "$RPRE\nok:   something  (ok)\nOVERALL: ok (67 checks)"
# test_dblclick_connected_grow.tcl:334, test_select_same_net_by_label.tcl:259
set R_DBL    "$RPRE\nok:   something  (ok)\nOVERALL: ok  (all checks passed)"
# the counted failure spelling the two counted suites print when they fail
set R_FAILED "$RPRE\nFAIL: x -> {1} (exp {0}) : FAIL\nOVERALL: 1 FAILED (65 passed)"
# test_wire_split / test_crossview_paste / test_pin_type_edit
set R_NOTOK  "$RPRE\nok:   something  (ok)\nOVERALL: notok"
# the trailing-words trap: 0629's proposed {^OVERALL: ok} accepts this
set R_OKAY   "$RPRE\nok:   something  (ok)\nOVERALL: okay then"
# the word-boundary trap: 0492's proposed \M form accepts this
set R_TAB    "$RPRE\nOVERALL: ok\tand then some"
# the banner quoted inside a check name -- whole-line rule, same contract as F
set R_FORGED "$RPRE\nok:   the suite ends by printing OVERALL: ok (30 checks)  (ok)"

# a suite that reported and THEN died: exit 0, banner present, death at column 0
set R_DIE_BARE  "$RPRE\nok:   something  (ok)\nOVERALL: ok\nTcl_AppInit() error: can not execute /tmp/probe.tcl, please fix:"
set R_DIE_FATAL "$RPRE\nok:   something  (ok)\nFATAL: signal 11 caught, exiting"
# both death literals present, but only ever mid-line
set R_DIE_MID   "$RPRE\nok:   a log may quote Tcl_AppInit() error mid-line  (ok)\nok:   and FATAL: signal too  (ok)\nOVERALL: ok"
# died before it ever reported
set R_NOBANNER  "$RPRE\nok:   something  (ok)\nok:   another  (ok)"

# --- K1-K4: what MUST be accepted -------------------------------------------
check "K1 completion banner, bare (the 131-site shape)"        [banner_complete $R_BARE] YES
check "K2 completion banner + a check count (0689's false red)" [banner_complete $R_C30] YES
check "K3 completion banner + the post-0690 ihp count"          [banner_complete $R_C67] YES
check "K4 completion banner + a double-space trailer"           [banner_complete $R_DBL] YES

# --- K5-K8: what MUST be rejected -------------------------------------------
check "K5 counted failure spelling is not a completion"      [banner_complete $R_FAILED] NO
check "K6 the notok failure spelling is not a completion"    [banner_complete $R_NOTOK]  NO
check "K7 trailing words after the banner are not a completion (0629/0492 traps)" \
      [list [banner_complete $R_OKAY] [banner_complete $R_TAB]] {NO NO}
check "K8 the banner forged inside a check name is not a completion" \
      [banner_complete $R_FORGED] NO

# --- K9-K11: the death predicate --------------------------------------------
check "K9 appinit death literal at column 0 is a death"      [banner_died $R_DIE_BARE]  YES
check "K10 fatal-signal literal at column 0 is a death"      [banner_died $R_DIE_FATAL] YES
check "K11 a clean log, and both literals mid-line only, are not deaths" \
      [list [banner_died $R_BARE] [banner_died $R_DIE_MID]] {NO NO}

# --- K12-K16: the composite verdict -----------------------------------------
check "K12 exit 0 + banner + a death marker -> FAILED (the hollow pass)" \
      [case_failed 0 $R_DIE_BARE] YES
check "K13 exit 0 + counted banner + no death -> not failed (0689 proper)" \
      [case_failed 0 $R_C30] NO
check "K14 nonzero exit + an empty log -> FAILED (0016 Part 4 arm intact)" \
      [case_failed 1 {}] YES
check "K15 exit 0 + no banner at all -> FAILED (died before reporting)" \
      [case_failed 0 $R_NOBANNER] YES
check "K16 exit 127 + a counted banner -> FAILED (child code beats any banner)" \
      [case_failed 127 $R_C30] YES

# --- K17: the single-builder lock -------------------------------------------
# The defect survived four filings because the shape was copied, not shared.
# run_regression.tcl must CALL the shared predicate and keep no private copy.
set RR [file join $repo tests run_regression.tcl]
set rr ""
if {[catch {set fh [open $RR r]; set rr [read $fh]; close $fh} e]} { set rr "<unreadable: $e>" }
set rr_code {}
foreach ln [split $rr \n] { if {![regexp {^[ \t]*#} $ln]} { lappend rr_code $ln } }
set rr_code [join $rr_code \n]
check "K17 run_regression sources the shared rule and keeps no private copy" \
      [list [regexp {banner_rule\.tcl} $rr_code] \
            [regexp {regression_case_failed} $rr_code] \
            [regexp {regexp[^\n]*OVERALL: ok} $rr_code]] {1 1 0}

# --- K18: two-reader equivalence, by VERDICT not by spelling ----------------
# run_suites.sh cannot source a Tcl file, so its copy of the rule stays an ERE.
# Extract it from the source and run it, exactly as C44 does for the skip rule.
set RS [file join $repo tests headless run_suites.sh]
set rs ""
if {[catch {set fh [open $RS r]; set rs [read $fh]; close $fh} e]} { set rs "<unreadable: $e>" }
set rs_re ""
regexp {grep -qE '(\^OVERALL: ok[^']*)'} $rs -> rs_re
proc grep_ere {re blob} {
  if {$re eq {}} { return "<no-ere>" }
  if {[catch {exec grep -qE -- $re << $blob}]} { return NO }
  return YES
}
set k18_tcl {}; set k18_sh {}
foreach fx [list $R_BARE $R_C30 $R_C67 $R_DBL $R_FAILED $R_NOTOK $R_OKAY $R_FORGED] {
  lappend k18_tcl [banner_complete $fx]
  lappend k18_sh  [grep_ere $rs_re $fx]
}
check "K18 banner_complete and run_suites.sh's ERE agree on all 8 fixtures" \
      [list [expr {$rs_re ne {}}] $k18_tcl] [list 1 $k18_sh]

# --- K19: the death literals are full_audit.sh's own, extracted from source --
# Not a spelling comparison: full_audit's arms are shell EREs and banner_died is
# a Tcl regexp. Build the fixtures FROM full_audit's literals and assert the Tcl
# predicate fires on them, so a re-spelling on either side stays honest and a
# widening on one side alone reddens here.
set fa_fatal ""; set fa_appinit ""
regexp {line_has '(\^FATAL: signal)'} $fa -> fa_fatal
regexp {line_has '(\^Tcl_AppInit\\\(\\\) error)'} $fa -> fa_appinit
proc ere_to_line {e} {
  set s [string range $e 1 end]            ;# drop the ^ anchor
  return [string map [list {\(} ( {\)} )] $s]
}
set k19_f ""; set k19_a ""
if {$fa_fatal   ne ""} { set k19_f [banner_died "ok:   x  (ok)\n[ere_to_line $fa_fatal] 11 caught, exiting"] }
if {$fa_appinit ne ""} { set k19_a [banner_died "ok:   x  (ok)\n[ere_to_line $fa_appinit]: can not execute /tmp/probe.tcl, please fix:"] }
check "K19 the death predicate fires on full_audit's own two crash literals" \
      [list [expr {$fa_fatal ne {}}] [expr {$fa_appinit ne {}}] $k19_f $k19_a] {1 1 YES YES}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
