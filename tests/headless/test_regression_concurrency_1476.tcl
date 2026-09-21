# tests/headless/test_regression_concurrency_1476.tcl
#
# Issue 1476 -- TWO REGRESSION RUNS IN ONE TREE CORRUPT EACH OTHER, IN FOUR
# DISTINCT WAYS, AND THE DANGEROUS ONE IS SILENT.
#
# `tclsh run_regression.tcl` assumes it is the only run in the tree. It is not:
# this user runs crews that verify in parallel by design, and two T1s in one
# clone destroy each other's evidence. Filed FIVE times across seven weeks --
# 0384, 0867, 0990, 0955, 0905 -- and never once attempted, because 0990 said a
# red "would have to run two regressions at once, which is expensive". Measured
# 2026-09-16: that premise is FALSE. One CASE reproduces it, and the miniature
# in section D below reproduces it in seconds with 1500 `sleep 0.02` shell jobs
# and no xschem at all. Seventeen days of "too expensive" rested on a sentence
# nobody re-measured. Re-measure the sentences in this header too.
#
# THE FOUR FACES, and which section pins each:
#
#   FACE 1, phantom FATALs -- sections S1/R/D. `$workroot` is a FIXED path
#     (`open_close.tcl:38`, `create_save.tcl:32`, `netlisting.tcl:38`); one run
#     deletes it while another is still collating; `read_job_status`
#     (`test_utility.tcl:118-125`) scores the missing status file `-1`; the
#     caller prints a counted `FATAL ... : exit -1`. Measured: 660/1500 jobs.
#
#   FACE 2, the second run dies with NO VERDICT -- sections S2/D. The startup
#     wipe `file delete -force $testname/results` (`open_close.tcl:32`) is
#     UNGUARDED, and it raises when the other run is creating files inside that
#     tree mid-walk. rc 1, no banner, no `Total num fail:` line. Face 1 screams;
#     face 2 vanishes, and the driver counts the lines that are THERE.
#
#   FACE 3, silent result-file loss -- section C. `cleanup_debug_files`
#     (`test_utility.tcl:102-114`) `catch`es its `xargs ... awk` and discards
#     the result, so a file the other run deleted is never reported. Worse than
#     "never counted": gawk's "cannot open file" is a FATAL, so ONE missing file
#     aborts the whole `xargs -n 64` batch and up to 63 files that WERE there
#     are silently left un-normalised. Section C pins that deterministically.
#
#   (ISSUE 1487, face 4's quieter sibling -- section V5. A run reports ZERO
#     having verified LESS: `summarize_all` dropped every `skip:` line and every
#     `RESULT:` check count, so a case that could not run six of its rows left
#     a block identical to one that ran them all. Measured on the stage-F gate
#     of the outsider-fixes batch: 8 skips in the case logs, 0 in the verdict.)
#
#   FACE 4, phantom PASS -- sections V. `run_regression.tcl`'s
#     `set log_fn "results.log"` and the `open ... w` that follows it: fixed
#     name, truncate, no lock. (Cite the MEANING, not a line number -- C1's lock
#     moved both, and the numbers this header first carried are already stale.)
#     A run can report ZERO having verified nothing, into the one file CLAUDE.md
#     calls "THE ONLY PLACE THE ANSWER IS".
#
# ⚠ FACE 4 IS NOT A CORRUPTION, IT IS AN ERASURE, AND THE FIRST DRAFT OF THIS
# SUITE GOT IT WRONG. The obvious rows -- "the verdict file has no NUL bytes",
# "the verdict file is not a mixture of two runs" -- are GREEN ON TODAY'S TREE.
# Measured 3/3: the file ends up 13268 bytes with ZERO NUL bytes and run A's
# verdict complete and well-formed, while run B's ENTIRE verdict is gone and run
# B exits 0 printing `Finish b1.tcl (headless)`. Nothing is damaged; a whole
# run's answer simply never existed. Row V2a is keyed on the ERASURE (B's block
# absent AND B never said so), which is the thing that actually reds.
#
# ⚠ AND NEITHER SHAPE IN THE PLAN FIXES IT. Measured 2026-09-16, the miniature
# of section D run as a staggered pair in three configurations:
#
#   workroot expression                      run A          run B
#   "$testname/results/.work"   (today)      660 phantoms   DIED at startup
#   "$testname/results/.work.[pid]"          658 phantoms   DIED at startup
#   "$testname/.work.[pid]"                  0 phantoms     DIED at startup (2 of 3)
#
# Pid-scoping `.work` INSIDE `results/` changes nothing, because the shared
# thing is `results/` itself and each run wipes it at startup. Moving the
# workroot OUT of `results/` fixes face 1 and is FLAKY on face 2 -- and it is
# the configuration that first reproduced FACE 3 (11 `awk: cannot open file`,
# `pathlist=1500 present=844`, run A still reporting `fatals=0` over 656 files
# that are gone). A fix measured once on that shape would look green. The rows
# here assert the PROPERTY -- both runs finish and report -- not a spelling, so
# they stay red until the defect is actually closed rather than until the
# recommended edit is typed.
#
# ⚠ WHY THE BEHAVIOURAL ROWS BUILD A MINIATURE AND NEVER TOUCH tests/open_close/.
# This suite is meant to be registered in T1, and T1's baseline is ZERO. A row
# that provoked a real collision in the shared `tests/open_close/` tree WHILE T1
# was running would corrupt the very run executing it. Section D therefore
# builds a private case under this suite's own per-pid scratch, drives the REAL
# helper procs out of `tests/test_utility.tcl`, and reconstructs `open_close`'s
# two load-bearing lines BY COPYING THEM OUT OF THE REAL FILE -- so whatever B1
# changes them to is what this fixture runs, and the rows flip green with the
# fix rather than needing an edit here.
#
# ⚠ THE BEHAVIOURAL ROWS ARE RACES, AND A GREEN ONE IS NOT PROOF ON ITS OWN.
# D1a (660 phantom `exit -1`) reproduced 6/6 and is the ANCHOR: it is what shows
# the fixture provoked a collision at all. D2a/D2b (the second run dying) is the
# same idiom as W5a in test_suite_watchdog_1403.tcl -- it pins the OUTCOME, and
# a fixture that stopped provoking would leave it green. If D2a is green while
# D1a is red, the fixture is what needs looking at, not the fix.
#
# REGISTERED IN T1. Task C1 added this suite to `hcases` in
# `tests/run_regression.tcl`, so it now runs inside the very regression sweep
# whose concurrency it measures. That is safe because both of its driver copies
# run with cwd inside this suite's own per-pid scratch, so their verdict file
# AND their verdict lock are `<scratch>/results.log`, never the live run's.
# `full_audit.sh:393` also picks this file up through its
# `ls "$HERE"/test_*.tcl` glob.
#
# ⚠ FLOOR: 46 checks, and it only ever goes up. 13 were RED when this suite was
# written, and 7 were the non-vacuity and guard rows that had to be green from
# the start; ALL 20 were green as of the B1 and C1 fixes, so a red one now is a
# REGRESSION rather than an unfixed face (V1b is the one that reds if
# `results.log` is ever renamed, which ruling R1 forbids). Section V5 (issue
# 1487) took it to 44: the verdict must say what did NOT run. Its fix round
# added V5g and V5h -- 46: a carried line may not forge the verdict's own
# structure, and a suite that states its size only in its banner is not dropped.
#
#   headless -> 46 checks
#     ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_regression_concurrency_1476.tcl
#
# Spec/notes: doc/claude/harness_concurrency_batch/PLAN.md, DECISIONS.md (R1).

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail" ; incr npass } else { puts "FAIL: $name $detail" ; incr fail }
}
## Substring test that never treats the needle as a glob pattern.
proc has_text {haystack needle} { expr {[string first $needle $haystack] >= 0} }

proc slurp {p} {
  if {[catch {open $p r} f]} { return {} }
  set t [read $f] ; close $f ; return $t
}
proc spit {p body} {
  set f [open $p w] ; puts -nonewline $f $body ; close $f ; return $p
}
proc count_lines {txt needle} {
  set n 0
  foreach l [split $txt \n] { if {[string first $needle $l] >= 0} { incr n } }
  return $n
}
proc count_re {txt re} {
  set n 0
  foreach l [split $txt \n] { if {[regexp -- $re $l]} { incr n } }
  return $n
}
## The first line of $txt matching $re, or {} -- the house idiom for reading a
## driver's source (test_suite_watchdog_1403.tcl's rr_cmdline, row V57 of
## test_op_annot.tcl). Cite what the line MEANS, never a bare line number.
proc src_line {txt re} {
  foreach l [split $txt \n] { if {[regexp -- $re $l]} { return $l } }
  return {}
}

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
set tdir    [file join $repo tests]
set scratch [test_scratch conc1476]
set xbin    [file join $repo src xschem]

set CASES [list open_close create_save netlisting]
foreach c $CASES { set SRC($c) [slurp [file join $tdir $c.tcl]] }
set UTIL_PATH [file join $tdir test_utility.tcl]
set UTIL [slurp $UTIL_PATH]
set RR   [slurp [file join $tdir run_regression.tcl]]

## The two load-bearing expressions, per case file.
##   WORKROOT  the right-hand side of `set workroot ...`  (face 1's fixed path)
##   RESULTS   the argument of the startup `file delete -force ...results`
foreach c $CASES {
  set WR($c)  {}
  set RES($c) {}
  set l [src_line $SRC($c) {^[ \t]*set[ \t]+workroot[ \t]}]
  if {$l ne {}} { regexp {^[ \t]*set[ \t]+workroot[ \t]+(.*[^ \t])[ \t]*$} $l -> WR($c) }
  set l [src_line $SRC($c) {file delete -force[^\n]*results}]
  set WIPELINE($c) $l
  if {$l ne {}} { regexp {file delete -force[ \t]+(\S+)} $l -> RES($c) }
}

# =============================================================================
# SECTION S -- the three case files, read as source (faces 1 and 2, cheap)
# =============================================================================

## S3a first: the other six rows are vacuous if the extraction found nothing.
## A row that silently stops finding its subject is a row that stops working.
set _got 1
foreach c $CASES { if {$WR($c) eq {} || $RES($c) eq {}} { set _got 0 } }
check S3a-both-expressions-were-found-in-all-three-case-files [expr {$_got}] \
  "-- workroot + the startup results wipe, from open_close/create_save/netlisting; S1 and S2 measure nothing without these"

## ⚠ S1 PINS THE RECOMMENDED SHAPE, `[pid]`, because ruling R1 names it: "the
## pid scope the runner already uses one file away (test_utility.tcl:82,
## .parallel_jobs.[pid])". The PROPERTY -- two concurrent runs do not share
## scratch -- is what section D measures. This row is the cheap structural half.
foreach c $CASES {
  check S1-$c-workroot-is-per-run [has_text $WR($c) {[pid]}] \
    "-- observed `set workroot $WR($c)`; the requirement is a per-run, \[pid\]-scoped path, because when two runs of this case SHARE one scratch dir whichever finishes first deletes it out from under the other"
}

## ⚠ S2 ACCEPTS EITHER RESOLUTION, DELIBERATELY. Face 2 is the case dying with
## no verdict when the startup wipe raises. Two honest fixes: GUARD the wipe so
## its failure is a named outcome, or make the results root per-run so nothing
## can race it. A row that demanded only one of them would false-red a correct
## fix -- and this file does not get to choose B1's design.
foreach c $CASES {
  set _guarded [has_text $WIPELINE($c) {catch}]
  set _perrun  [has_text $RES($c) {[pid]}]
  check S2-$c-startup-wipe-cannot-die-silently [expr {$_guarded || $_perrun}] \
    "-- observed `[string trim $WIPELINE($c)]`; guarded-by-catch=$_guarded per-run-target=$_perrun, and EITHER one suffices. With NEITHER, the wipe raises while the other run is creating files inside that tree mid-walk, the case exits 1 with NO banner and NO `Total num fail:` line, and summarize_all counts the lines that are there"
}

# =============================================================================
# SECTION R -- read_job_status conflates "missing" with "garbled" (face 1 root)
# =============================================================================
# Deterministic, race-free, against the REAL proc in a child tclsh (sourcing
# test_utility.tcl into THIS interpreter would define print_results and
# xschem_cmd beside xschem's own globals).

set rdir [file join $scratch rjs] ; file mkdir $rdir
spit [file join $rdir good.status] "0\n"
spit [file join $rdir bad.status]  "xyzzy\n"
spit [file join $rdir ten.status]  "10\n"

set rprobe [spit [file join $scratch rjs_probe.tcl] "source [list $UTIL_PATH]
proc probe {p} {
  if {\[catch {read_job_status \$p} r\]} { return \"RAISED:\$r\" }
  return \"RET:\$r\"
}
puts \"MISSING \[probe [list [file join $rdir nosuch.status]]\]\"
puts \"GARBLED \[probe [list [file join $rdir bad.status]]\]\"
puts \"VALID0  \[probe [list [file join $rdir good.status]]\]\"
puts \"VALID10 \[probe [list [file join $rdir ten.status]]\]\"
"]
set rout {}
catch {exec timeout 60 tclsh $rprobe 2>@1} rout
proc probe_val {txt key} {
  foreach l [split $txt \n] {
    if {[regexp "^$key\[ \t\]+(.*)\$" [string trim $l] -> v]} { return [string trim $v] }
  }
  return {}
}
set _miss [probe_val $rout MISSING]
set _garb [probe_val $rout GARBLED]
set _v0   [probe_val $rout VALID0]
set _v10  [probe_val $rout VALID10]

check R1a-missing-is-distinguishable-from-garbled \
  [expr {$_miss ne {} && $_garb ne {} && $_miss ne $_garb}] \
  "-- missing=$_miss garbled=$_garb, and these two must DIFFER; while ONE code answers both, the caller cannot tell \"the other run deleted my status file\" from \"the job wrote nonsense\" and prints the same `exit` line for either"
check R1b-a-real-status-is-returned-verbatim \
  [expr {$_v0 eq {RET:0} && $_v10 eq {RET:10}}] \
  "-- 0=$_v0 10=$_v10; the non-vacuity half: whatever R1a is fixed with must not disturb the codes a job really wrote (netlisting treats 10 as an EXPECTED netlist error)"

# =============================================================================
# SECTION C -- cleanup_debug_files swallows what it could not clean (face 3)
# =============================================================================
# Deterministic and race-free. `cleanup_debug_file.awk` only writes a file back
# from endfile() when a pattern matched, and END{endfile()} is the only thing
# that flushes the LAST file of a batch -- so a gawk FATAL loses work on files
# that were perfectly present. `catch {exec xargs ...}` with no result variable
# then tells the caller nothing at all.

set cdir [file join $scratch cln] ; file mkdir $cdir
file copy -force [file join $tdir cleanup_debug_file.awk] $cdir
## "trim_wires ..." is one of the patterns the awk rewrites.
set _mk "some preamble\ntrim_wires this text must be removed\n"
spit [file join $cdir solo_debug.txt] $_mk
spit [file join $cdir sibling_debug.txt] $_mk

set cprobe [spit [file join $scratch cln_probe.tcl] "source [list $UTIL_PATH]
cd [list $cdir]
proc norm {p} { set f \[open \$p r\] ; set t \[read \$f\] ; close \$f
  return \[expr {\[string first {trim_wires ***Removed***} \$t\] >= 0}\] }
set rc1 \[catch {cleanup_debug_files \[list [list [file join $cdir solo_debug.txt]]\] 2} r1\]
puts \"ALONE \[norm [list [file join $cdir solo_debug.txt]]\]\"
set rc2 \[catch {cleanup_debug_files \[list [list [file join $cdir sibling_debug.txt]] [list [file join $cdir never_written_debug.txt]]\] 2} r2\]
puts \"BATCHED \[norm [list [file join $cdir sibling_debug.txt]]\]\"
puts \"TOLD \[expr {\$rc2 != 0 || \[string trim \$r2\] ne {}}\]\"
"]
set cout {}
catch {exec timeout 60 tclsh $cprobe 2>@1} cout
set _alone   [probe_val $cout ALONE]
set _batched [probe_val $cout BATCHED]
set _told    [probe_val $cout TOLD]

check C1a-a-file-on-its-own-is-normalised [expr {$_alone eq {1}}] \
  "-- alone=$_alone (1 = the awk rewrote the lone file it was handed); the non-vacuity half -- unless the awk really does rewrite a file on its own, C1b would be measuring a no-op rather than a LOSS"
check C1b-a-missing-file-does-not-silently-cost-its-batch-mates \
  [expr {$_batched eq {1} || $_told eq {1}}] \
  "-- batched=$_batched told-the-caller=$_told, and EITHER one suffices; one absent file makes gawk exit FATAL, so with NEITHER, up to 63 files that WERE there go unprocessed in that `xargs -n 64` batch and `catch {exec ...}` with no result variable reports none of it"

# =============================================================================
# SECTION D -- the miniature concurrent pair (faces 1 and 2, behavioural)
# =============================================================================
# A private case under this suite's own scratch, never tests/open_close/. It
# uses the REAL run_parallel_cmds / read_job_status / cleanup_debug_files, and
# reconstructs open_close's startup wipe and workroot lines by COPYING THEM OUT
# OF THE REAL FILE, so B1's edit lands in this fixture automatically.

set MINI_JOBS  1500
set MINI_SLEEP 0.02
set MINI_STAG  1

set MINI_TMPL {source @UTIL@

set testname $::env(MINI_TAG)
set pathlist {}
set num_fatals 0

if {![file exists $testname]} { file mkdir $testname }

## open_close.tcl's UNGUARDED startup wipe, copied from the real file.
if {[catch {file delete -force @RESULTS@} e]} {
  puts "MINI-STARTUP-DIED: $e"
  exit 1
}
file mkdir @RESULTS@

set cwd [pwd]
## open_close.tcl's workroot expression, copied VERBATIM from the real file.
set workroot @WORKROOT@
file mkdir $workroot

set jobs {}
set NJ $::env(MINI_JOBS)
set SL $::env(MINI_SLEEP)
for {set idx 0} {$idx < $NJ} {incr idx} {
  set fn_debug "job${idx}_debug.txt"
  set output "@RESULTS@/$fn_debug"
  set status "$cwd/$workroot/$idx.status"
  set tmpdir "$cwd/$workroot/$idx.tmp"
  set cmd "mkdir -p '$tmpdir' && sleep $SL && echo 'mini ok' > '$cwd/$output'; echo \$? > '$status'"
  lappend jobs [list $fn_debug "$cwd/$output" $status $cmd]
}

set njobs [test_njobs]
set cmds {}
foreach j $jobs { lappend cmds [lindex $j 3] }
run_parallel_cmds $cmds $njobs

set cleanlist {}
foreach j $jobs {
  lassign $j fn_debug output status cmd
  set rc [read_job_status $status]
  if {$rc != 0} {
    puts "FATAL: $cmd : exit $rc"
    incr num_fatals
  } else {
    lappend pathlist $fn_debug
    lappend cleanlist $output
  }
}
cleanup_debug_files $cleanlist $njobs
file delete -force $workroot

set present 0
foreach f $pathlist { if {[file exists "@RESULTS@/$f"]} { incr present } }
puts "MINI-RESULT fatals=$num_fatals pathlist=[llength $pathlist] present=$present"
flush stdout
}

set PAIR_SH {#!/bin/sh
# $1 cwd  $2 script  $3 util  $4 jobs  $5 sleep  $6 stagger
cd "$1" || exit 2
MINI_UTIL="$3" ; MINI_TAG=minicase ; MINI_JOBS="$4" ; MINI_SLEEP="$5"
export MINI_UTIL MINI_TAG MINI_JOBS MINI_SLEEP
timeout 200 tclsh "$2" > A.out 2> A.err &
AP=$!
sleep "$6"
timeout 200 tclsh "$2" > B.out 2> B.err
echo $? > B.rc
wait $AP
echo $? > A.rc
exit 0
}

set mdir [file join $scratch mini] ; file mkdir $mdir
file copy -force [file join $tdir cleanup_debug_file.awk] $mdir
set mini_tcl [spit [file join $mdir mini_case.tcl] \
  [string map [list @UTIL@ [list $UTIL_PATH] \
                    @RESULTS@ $RES(open_close) \
                    @WORKROOT@ $WR(open_close)] $MINI_TMPL]]
set mini_sh [spit [file join $scratch mini_pair.sh] $PAIR_SH]

set _t0 [clock milliseconds]
set mrc 0
if {[catch {exec timeout 280 sh $mini_sh $mdir $mini_tcl $UTIL_PATH \
                 $MINI_JOBS $MINI_SLEEP $MINI_STAG 2>@1} _mo opt]} {
  set ec [dict get $opt -errorcode]
  set mrc [expr {[lindex $ec 0] eq {CHILDSTATUS} ? [lindex $ec 2] : 1}]
}
set _mel [expr {[clock milliseconds] - $_t0}]
set Aout [slurp [file join $mdir A.out]]
set Bout [slurp [file join $mdir B.out]]
set Arc  [string trim [slurp [file join $mdir A.rc]]]
set Brc  [string trim [slurp [file join $mdir B.rc]]]

## D0a: the fixture ran at all. rc 124 is `timeout`'s, and a stall must be a
## NAMED OUTCOME rather than the absence of one.
check D0a-the-miniature-pair-ran [expr {$mrc != 124 && $Aout ne {} && $Bout ne {}}] \
  "-- pair rc=$mrc in ${_mel}ms, A.out [string length $Aout]B, B.out [string length $Bout]B; $MINI_JOBS jobs each, ${MINI_STAG}s stagger, entirely inside this suite's scratch"

set _ph [count_lines $Aout {: exit -1}]
check D1a-no-phantom-exit-minus-1-in-the-collating-run [expr {$_ph == 0}] \
  "-- $_ph counted `FATAL ... : exit -1` lines out of $MINI_JOBS jobs, and the requirement is ZERO; each such line WOULD BE a job that RAN FINE whose status file the other run deleted. This row is the ANCHOR: while it is red the fixture is provoking a real collision"

check D2a-the-second-run-reaches-a-verdict [has_text $Bout {MINI-RESULT}] \
  "-- B said: [expr {[has_text $Bout {MINI-RESULT}] ? [string trim [src_line $Bout {MINI-RESULT}]] : ([has_text $Bout {MINI-STARTUP-DIED}] ? [string trim [src_line $Bout {MINI-STARTUP-DIED}]] : {NOTHING -- neither a MINI-RESULT line nor a MINI-STARTUP-DIED line})}]; a run that dies here contributes NO `Total num fail:` line at all, so the driver counts only the runs that survived"
check D2b-the-second-run-exits-zero [expr {$Brc eq {0}}] \
  "-- B rc=$Brc, and 0 is the requirement; face 2 is worse than face 1 precisely because it is quiet -- face 1 screams in the log, face 2 leaves nothing behind to count"

# =============================================================================
# SECTION P -- the 83 files UPSTREAM of the verdict (issue 1478)
# =============================================================================
# ⚠ THE LOCK PROTECTED 1 OF 88. This section exists because the batch's own
# decision record asserted, on the day the decision was taken, that "the only
# single-slot object left was the name tests/results.log". MEASURED FALSE: a full
# T1 writes **88 fixed-name files** under tests/ --
#
#     3 tcases x (<tc>.log + <tc>_output.txt)  =  6
#    69 hcases x  <hc>.log                     = 69
#    11 dcases x  <dc>.disp.log                = 11
#       stefan_xschemtest.log + results.log    =  2
#                                         total  88
#
# -- of which **83 are verdict INPUTS**: summarize_all and regression_case_failed
# are applied to their contents. Fixing results.log while those stand means each
# run writes a correct-LOOKING verdict computed from the other run's bodies.
#
# ⚠ AND THE COLLISION WAS REPRODUCED, WRONG IN BOTH DIRECTIONS, using the tree's
# own shipped banner_rule.tcl as the scorer:
#   * SILENTLY (both children exit 0, the ordinary shape) run A's TWO REAL
#     FAILURES were counted as **0**. That is face 4 -- the dangerous direction --
#     one file upstream of the file the lock guards.
#   * and the PASSING run counted a failure it did not earn.
#
# The cure is the one B1 already proved one directory away: a `.<pid>` infix,
# then PUBLISH back to the canonical name. These rows pin the naming; V3a pins
# the property behaviourally.

set UTIL_NOW [slurp $UTIL_PATH]

## P1 -- the three redirection sites, per site, in the idiom of W15c in
## test_suite_watchdog_1403.tcl: isolate the ONE line that writes the file and
## require it not to name the shared spelling. A row that grepped the whole loop
## would match the PROSE about the file as readily as the file (issue 0894).
foreach {_psite _pvar _pbare} [list \
    tcases-output tccmd {${tc}_output.txt} \
    hcases-log    hccmd {${hc}.log} \
    dcases-displog dccmd {${dc}.disp.log}] {
  set _pl [src_line $RR "eval exec \\\$$_pvar"]
  check P1-$_psite-is-written-under-a-per-run-name \
    [expr {$_pl ne {} && ![has_text $_pl $_pbare] ? 1 : 0}] \
    "-- observed `[string trim $_pl]`; the requirement is that this redirection NOT name the shared `$_pbare`. One slot per suite NAME rather than per RUN is what let two runs score each other's bodies"
}

## P1d -- and the same for the file the CASE writes rather than the driver.
## <case>.log is produced by print_results in tests/test_utility.tcl, in a CHILD
## process, so the driver cannot simply pick the name: the tag is handed down in
## the environment. A bare `open "$testname.log" w` there puts the shared name
## back however careful the driver is.
check P1d-print_results-writes-a-per-run-log \
  [expr {[has_text $UTIL_NOW {t1_run_file}] && ![regexp {open[^\n]*"\$testname\.log"[^\n]*w} $UTIL_NOW] ? 1 : 0}] \
  "-- test_utility.tcl helper=[has_text $UTIL_NOW {t1_run_file}] bare-open=[expr {[regexp {open[^\n]*"\$testname\.log"[^\n]*w} $UTIL_NOW] ? 1 : 0}]; print_results runs in the case's own process, so the driver and the case must agree on the name by construction rather than by luck"

## ⚠ P1e/P1f ARE THE ONLY BEHAVIOURAL ROWS IN THIS SECTION, AND THEY EXIST
## BECAUSE THE SOURCE ROWS ABOVE CANNOT REACH THE RISK. <case>.log is written by
## print_results in the CASE's process and read back by the DRIVER's, so the two
## must agree on a name across a process boundary. Get that handshake wrong and
## the driver looks for a file the case never wrote -- summarize_all takes its
## missing-log branch and synthesizes `case produced no log (never ran?): FAIL`,
## A COUNTED FAILURE THAT NEVER HAPPENED, in the suite whose baseline is ZERO.
## ⚠ AND SECTION V CANNOT CATCH IT EITHER: its two driver copies run with
## `set tcases {}`, so the golden-case path is never walked there.
set pdir [file join $scratch pr] ; file mkdir $pdir
set pprobe [spit [file join $scratch pr_probe.tcl] "source \[lindex \$argv 0\]
cd \[lindex \$argv 1\]
set ::env(T1_LOG_TAG) 4242
print_results tagcase {} 0
if {\[catch {t1_run_file tagcase .log} r\]} { set r NO-SUCH-PROC }
puts \"TAGGED \[file exists tagcase.4242.log\]\"
puts \"CANON \[file exists tagcase.log\]\"
puts \"AGREE \[expr {\$r eq {tagcase.4242.log}}\]\"
unset ::env(T1_LOG_TAG)
print_results plaincase {} 0
puts \"PLAIN \[file exists plaincase.log\]\"
"]
set pout {}
catch {exec timeout 60 tclsh $pprobe $UTIL_PATH $pdir 2>@1} pout
set _ptag   [probe_val $pout TAGGED]
set _pcanon [probe_val $pout CANON]
set _pagree [probe_val $pout AGREE]
set _pplain [probe_val $pout PLAIN]

check P1e-the-case-and-the-driver-agree-on-the-log-name-across-processes \
  [expr {$_ptag eq {1} && $_pcanon eq {0} && $_pagree eq {1}}] \
  "-- with T1_LOG_TAG=4242 set: print_results wrote tagcase.4242.log=$_ptag, wrote the shared tagcase.log=$_pcanon (must be 0), and t1_run_file names the same file=$_pagree. If these disagree the driver summarizes a file that was never written and counts a failure that never happened"
check P1f-an-untagged-run-still-writes-the-name-people-type \
  [expr {$_pplain eq {1}}] \
  "-- with T1_LOG_TAG unset: plaincase.log=$_pplain. `cd tests && tclsh open_close.tcl` is the documented way to run one case by hand and CLAUDE.md says so; a private per-run name there would be a new thing to learn for no benefit, and the non-vacuity half of P1e"

## ⚠ P2a IS ISSUE 1478 §3, AND IT IS THE TRAP IN THIS WHOLE PART. The per-case
## FILE NAME GOES INTO THE VERDICT: summarize_all writes its argument as the
## block header (`puts $fd "$fn"`). Pid-qualify the name naively and every block
## header in results.log grows a pid -- which changes what the verdict CONTAINS,
## destroys the byte-determinism a green run has today, and breaks any reader
## keying on the literal `headless/<name>.disp.log`.
##
## 1478 proposed publishing back to the canonical name BEFORE summarizing. That
## works for the header and REOPENS THE RACE: between the rename and the read,
## the other run can publish its own file onto the same name and be summarized
## instead. The shape that closes both is to separate the two jobs -- READ the
## per-run file, PRINT the canonical name -- which is what a label argument does.
check P2a-the-block-header-is-the-canonical-name-not-the-per-run-one \
  [expr {[regexp {summarize_all[ \t]+\S+[ \t]+\$fd[ \t]+\S+} $RR] ? 1 : 0}] \
  "-- summarize_all must be handed the file to READ and, separately, the name to PRINT: `[string trim [src_line $RR {summarize_all[ \t]+\S+[ \t]+\$fd}]]`. Publishing first and summarizing after would fix the header and put the race back"

# =============================================================================
# SECTION V -- the verdict file (face 4)
# =============================================================================

## ⚠ V1b WAS REKEYED WHEN R1 WAS RE-DECIDED, AND THE OLD TEXT IS LEFT HERE
## BECAUSE IT IS THE POINT. It used to read:
##
##     check V1b-the-verdict-keeps-its-canonical-name
##       [regexp -line {^[ \t]*set[ \t]+log_fn[ \t]+"results\.log"[ \t]*$} $RR]
##
## -- a row written to enforce R1 AS FIRST RULED ("the second run waits; the
## verdict keeps ONE name"). The user rejected that shape -- *"Why not make it
## fault-tolerant and find a way for both runs to proceed?"* -- and they were
## right: the constraint the whole choice rested on was a FILENAME CONVENTION,
## not a property of the system. A row that pins a decision rather than a
## PROPERTY goes red the day the decision is improved, and it did.
##
## The property that actually matters survives both rulings and is what this row
## now asserts, in two halves:
##   1. `results.log` STILL EXISTS as a canonical name. crew.js, CLAUDE.md's
##      reading instructions and the user all name that exact file; the new
##      design keeps it, tracking the most recent COMPLETED run.
##   2. the run does NOT WRITE THROUGH IT. Each run's own verdict is
##      `results.<pid>.log`, so two runs never share the file they are writing
##      and neither is ever refused.
## Half 1 alone is the old row. Half 2 alone would bless deleting the canonical
## name. Both together are the ruling as re-decided.
check V1b-canonical-name-survives-AND-is-not-what-the-run-writes \
  [expr {[has_text $RR {results.log}] &&
         [regexp {results\.\[pid\]\.log} $RR] ? 1 : 0}] \
  "-- canonical `results.log` still named in the driver, AND a per-run verdict spelled `results.\[pid\].log`: [expr {[regexp {results\.\[pid\]\.log} $RR] ? {found} : {ABSENT}}]. With only the canonical name, two runs write one file and one answer is erased (face 4); with only the per-run name, every reader that spells `results.log` breaks"

## ⚠ V1f IS THE ROW THAT RETIRES THE REFUSAL. R1 as re-decided says NOBODY IS
## REFUSED: a second crew must never be told to go away, because this user runs
## crews that verify in parallel by design. The lock is DEMOTED to a safety net
## around the publish, not deleted -- V1a still requires it to exist -- but the
## `exit 2` and the REFUSING-TO-RUN banner must be gone, or "both runs proceed"
## is a sentence in a design document and not a property of the program.
check V1f-no-run-is-ever-refused \
  [expr {![has_text $RR {REFUSING TO RUN}] && ![regexp -line {^[ \t]*exit 2[ \t]*$} $RR] ? 1 : 0}] \
  "-- REFUSING-banner=[has_text $RR {REFUSING TO RUN}] bare-exit-2=[expr {[regexp -line {^[ \t]*exit 2[ \t]*$} $RR] ? 1 : 0}], and both must be 0. A refused run is a crew told its work cannot be verified right now, which is the cost R1 was re-decided to remove"

## ⚠ V1c IS THE LOAD-BEARING ONE AND IT LOOKS LIKE A DETAIL. The verdict channel
## has never been `fconfigure`d, so it is FULL-BUFFERED AT 4096 B against a
## ~4785-byte verdict. That makes a **0-byte** file the TYPICAL outcome of a
## killed run rather than an extreme one -- which is why issue 1477's truncated
## verdict is usually EMPTY rather than a proportional prefix. The trailer below
## survives buffering either way (it is written last, then closed); the HEADER
## does not, and the header is the half that says WHOSE answer a file is. Without
## this line the sentinels inherit the exact hole they were added to close.
check V1c-the-verdict-channel-is-line-buffered \
  [expr {[regexp {fconfigure[^\n]*-buffering[ \t]+line} $RR] ? 1 : 0}] \
  "-- `[string trim [src_line $RR {fconfigure[^\n]*-buffering}]]`; unbuffered-or-line is the difference between a killed run leaving a header that identifies it and a killed run leaving 0 bytes. (⚠ The needle here is deliberately the FULL expression: a bare `fconfigure` needle matched the COMMENT above the code and quoted that instead -- this batch's own D2 defect, a detail string that says something other than what the row measured)"

## V1d/V1e -- THE SENTINELS, which are worth more than the concurrency fix.
## They close two recorded traps that no amount of locking touches:
##   * THE FOSSIL. A stale `results.log` reads as a perfect clean sweep; only its
##     mtime ever said otherwise, and receipts plus a commit message in this tree
##     already carry a case count taken that way. A header naming pid and start
##     time makes a fossil self-identifying FROM CONTENT.
##   * 1477's TRUNCATION HOLE. Every prefix of a green run is itself a green run,
##     because all four counted shapes (FAIL$, GOLD?$, RESULT?$, ^FATAL) need a
##     line to EXIST. "No trailer => did not finish" is decidable where "short
##     file" is not.
## ⚠ NEITHER SENTINEL MAY END IN `FAIL` OR BEGIN WITH `FATAL` -- summarize_all's
## four counted shapes are applied to CASE logs, but a human, crew.js and every
## grep in CLAUDE.md read the verdict, and a sentinel that scored itself would be
## a self-inflicted phantom red. V4a checks that.
check V1d-the-verdict-carries-a-run-header \
  [expr {[has_text $RR {T1-RUN-BEGIN}] ? 1 : 0}] \
  "-- a header naming pid, script and start time; without it a verdict file cannot say whose answer it is, and the fossil trap has only mtime to defend it"
check V1e-the-verdict-carries-a-completion-trailer \
  [expr {[has_text $RR {T1-RUN-END}] ? 1 : 0}] \
  "-- a trailer naming pid, case count and counted failures; without it a run killed mid-write is indistinguishable from a clean sweep, because every prefix of a green run IS a green run"

check V1a-the-driver-serialises-the-verdict \
  [expr {[regexp -nocase {flock|lockfile|\.lock\M|lock_file|[a-z_]*lockf} $RR] ? 1 : 0}] \
  "-- lock evidence in run_regression.tcl: `[string trim [src_line $RR {(?i)flock|lockfile|\.lock\M|lock_file|[a-z_]*lockf}]]`. WITHOUT one the verdict file is opened mode `w` and the second run truncates the first's, with neither told. NOTE this is a WHOLE-FILE regexp that a mere comment satisfies -- V2a/V2b are the behavioural proof, never this row"

## The behavioural half. Two copies of the REAL driver, case lists neutered to
## /bin/sh stand-ins, sharing ONE private cwd -- never the repo's tests/.
set F4_A_CASES {a1 a2 a3 a4}
set fdir [file join $scratch f4] ; file mkdir $fdir
foreach f {test_utility.tcl banner_rule.tcl cleanup_debug_file.awk} {
  file copy -force [file join $tdir $f] $fdir
}
## The slow stand-in must emit MORE than one buffer's worth of countable lines,
## or run A's verdict never reaches the disk before run B truncates it and the
## whole race is invisible.
set slow [spit [file join $fdir slow.sh] "#!/bin/sh\nsleep 0.8\ni=0\nwhile \[ \$i -lt 200 \]; do echo \"\$i. thing: FAIL\"; i=\$((i+1)); done\necho \"OVERALL: ok\"\nexit 0\n"]
set fast [spit [file join $fdir fast.sh] "#!/bin/sh\ni=0\nwhile \[ \$i -lt 5 \]; do echo \"\$i. thing: FAIL\"; i=\$((i+1)); done\necho \"OVERALL: ok\"\nexit 0\n"]
foreach f [list $slow $fast] { catch {file attributes $f -permissions 0755} }

## Inject one line just before the first case loop -- i.e. AFTER the driver has
## opened its verdict file, which is the code under test.
proc mkdrv {src dst inj} {
  set out {} ; set done 0
  foreach l [split $src \n] {
    if {!$done && [regexp {^[ \t]*foreach[ \t]+tc[ \t]+\$tcases} $l]} {
      append out $inj \n ; set done 1
    }
    append out $l \n
  }
  spit $dst $out
  return $done
}
set _iA [mkdrv $RR [file join $fdir drvA.tcl] \
  "set tcases {} ; set dcases {} ; set hcases [list $F4_A_CASES] ; set xschem_cmd [list $slow]"]
set _iB [mkdrv $RR [file join $fdir drvB.tcl] \
  "set tcases {} ; set dcases {} ; set hcases [list b1] ; set xschem_cmd [list $fast]"]

set F4_SH {#!/bin/sh
# $1 cwd  $2 in-tree xschem (so a fallback can never name the installed 3.4.6)
cd "$1" || exit 2
XSCHEM="$2" ; export XSCHEM
timeout 120 tclsh drvA.tcl > A.out 2>&1 &
AP=$!
sleep 1.5
timeout 120 tclsh drvB.tcl > B.out 2>&1
echo $? > B.rc
wait $AP
echo $? > A.rc
exit 0
}
set f4_sh [spit [file join $scratch f4_pair.sh] $F4_SH]
set frc 0
if {[catch {exec timeout 200 sh $f4_sh $fdir $xbin 2>@1} _fo opt]} {
  set ec [dict get $opt -errorcode]
  set frc [expr {[lindex $ec 0] eq {CHILDSTATUS} ? [lindex $ec 2] : 1}]
}
set verdict [slurp [file join $fdir results.log]]
set f4Bout  [slurp [file join $fdir B.out]]
set f4Aout  [slurp [file join $fdir A.out]]
set f4Arc   [string trim [slurp [file join $fdir A.rc]]]
set f4Brc   [string trim [slurp [file join $fdir B.rc]]]
set _ablocks [count_re $verdict {^a[1-4]\.log$}]
set _bblocks [count_re $verdict {^b1\.log$}]

## The two per-run verdicts, found by CONTENT rather than by a pid this suite
## would otherwise have to scrape out of a shell script. Whichever file carries
## the `b1.log` block is run B's, and whichever carries the `a1.log` block is
## run A's -- an identification that keeps working if the naming is re-spelled.
set VA {} ; set VB {} ; set VA_F {} ; set VB_F {}
foreach _vf [lsort [glob -nocomplain -directory $fdir -- results.*.log]] {
  set _vt [slurp $_vf]
  if {[count_re $_vt {^b1\.log$}] > 0} { set VB $_vt ; set VB_F $_vf }
  if {[count_re $_vt {^a[1-4]\.log$}] > 0} { set VA $_vt ; set VB_F $VB_F ; set VA_F $_vf }
}
## "Did this run FINISH?" -- decidable from content, which is the whole of the
## 1477 fix. "Whose answer is this?" -- likewise, which is the whole of the
## fossil fix.
proc verdict_finished {txt} { expr {[regexp -line {^T1-RUN-END } $txt] ? 1 : 0} }
proc verdict_started  {txt} { expr {[regexp -line {^T1-RUN-BEGIN } $txt] ? 1 : 0} }
proc verdict_pid {txt re} {
  foreach l [split $txt \n] { if {[regexp -- "$re\[^\n\]*pid=(\[0-9\]+)" $l -> p]} { return $p } }
  return {}
}
## summarize_all's four counted shapes, verbatim (run_regression.tcl's own line).
proc counted_shapes {txt} {
  set n 0
  foreach l [split $txt \n] {
    if {[regexp {FAIL$} $l] || [regexp {GOLD\?$} $l] || [regexp {RESULT\?$} $l] || [regexp {^FATAL} $l]} { incr n }
  }
  return $n
}

check V0a-both-driver-copies-were-built [expr {$_iA && $_iB && $frc != 124}] \
  "-- injection A=$_iA B=$_iB, pair rc=$frc; without both, V2a and V2b measure nothing"
check V2b-the-first-run-verdict-is-complete [expr {$_ablocks == [llength $F4_A_CASES]}] \
  "-- $_ablocks of [llength $F4_A_CASES] case blocks in the CANONICAL results.log, [string length $verdict] bytes; the non-vacuity half, and now also issue 1478 §3's guard -- if the per-run naming ever leaked into the block HEADER these would be `a1.<pid>.log` and this count would drop to 0"

## ⚠ V2a REKEYED. It used to accept an ANNOUNCEMENT ("I refused, so I did not
## destroy anything") as an alternative to run B's answer existing. Under R1 as
## re-decided there is nothing to announce: nobody is refused, so the only
## acceptable outcome is that B's verdict EXISTS, complete, under its own name.
## The `|| $_announced` escape hatch is deliberately gone -- it is what made this
## row green on a tree where run B produced no answer at all.
check V2a-the-second-run-verdict-exists-in-its-own-right \
  [expr {$VB ne {} && [count_re $VB {^b1\.log$}] > 0 && [verdict_finished $VB]}] \
  "-- B's own verdict file=[expr {$VB_F eq {} ? {NONE FOUND} : [file tail $VB_F]}], b1 blocks=[expr {$VB eq {} ? 0 : [count_re $VB {^b1\.log$}]}], finished-trailer=[expr {$VB eq {} ? 0 : [verdict_finished $VB]}], B rc=$f4Brc. A second run that is refused, or whose verdict lands in a file the first run then overwrites, fails this row -- and a whole run reporting success while its answer never existed is face 4"

check V3a-both-runs-proceed-and-both-answers-survive \
  [expr {$VA ne {} && $VB ne {} && $VA_F ne $VB_F &&
         [count_re $VA {^a[1-4]\.log$}] == [llength $F4_A_CASES] &&
         [count_re $VB {^b1\.log$}] == 1}] \
  "-- A=[expr {$VA_F eq {} ? {NONE} : [file tail $VA_F]}] ([expr {$VA eq {} ? 0 : [count_re $VA {^a[1-4]\.log$}]}]/[llength $F4_A_CASES] blocks), B=[expr {$VB_F eq {} ? {NONE} : [file tail $VB_F]}] ([expr {$VB eq {} ? 0 : [count_re $VB {^b1\.log$}]}]/1). ⚠ This is the ruling itself, as a property: two runs collide and BOTH keep a complete answer. Concurrency buys no throughput here (measured 64.4 s concurrent against 53.7 s back-to-back, 20% WORSE) -- what it buys is that no crew is ever told its verification cannot run"

check V3b-neither-run-was-refused \
  [expr {$f4Arc eq {0} && $f4Brc eq {0} &&
         ![has_text $f4Aout {REFUSING TO RUN}] && ![has_text $f4Bout {REFUSING TO RUN}]}] \
  "-- A rc=$f4Arc B rc=$f4Brc, REFUSING banner A=[has_text $f4Aout {REFUSING TO RUN}] B=[has_text $f4Bout {REFUSING TO RUN}]. rc 2 is the old refusal; the user's instruction was to make it fault-tolerant so BOTH runs proceed rather than to pick which one is turned away"

## ⚠ V3c IS ISSUE 1477, AND IT IS THE HALF WORTH MORE THAN THE CONCURRENCY FIX.
## EVERY PREFIX OF A GREEN RUN IS ITSELF A GREEN RUN: all four counted shapes
## need a LINE TO EXIST, so a file cut short has FEWER lines to match and scores
## zero failures at every prefix length (verified at 1, 10, 40, 80, 120 and 170
## lines of a real 169-line verdict). The row proves the counted-shape scan is
## blind to truncation AND that the trailer is not -- both directions, or it
## would pass on a scan that is merely broken in a different way.
## ⚠ THE FIRST DRAFT OF THIS ROW ASSERTED THE WRONG THING AND IS WORTH RECORDING.
## It required `counted($full) == counted($cut)` -- "truncation does not change
## the count" -- which is FALSE and was measured false the moment the fix landed:
## run A's stand-in emits 200 FAIL lines per case, so the full verdict counts 800
## and a three-line prefix counts 1. The property is not that the count is
## PRESERVED; it is that the count can only go DOWN, i.e. toward "clean", so
## counting can never raise the alarm. Stating it as equality would have been a
## row that passed only on green fixtures and lied about the mechanism.
##
## The prefix used here is ONE LINE -- the header alone. That is the exact shape
## 1477 records: a run with 800 real failures, killed early, leaves a file that
## scores ZERO and reads as a perfect clean sweep. The trailer is the only thing
## that disagrees.
set _vfull $VA
set _vcut  [lindex [split $_vfull \n] 0]
check V3c-a-truncated-verdict-is-detectable-where-counting-is-blind \
  [expr {$_vfull ne {} && [verdict_finished $_vfull] && [counted_shapes $_vfull] > 0 &&
         ![verdict_finished $_vcut] && [counted_shapes $_vcut] == 0}] \
  "-- full verdict: finished=[expr {$_vfull eq {} ? {n/a} : [verdict_finished $_vfull]}] counted=[expr {$_vfull eq {} ? {n/a} : [counted_shapes $_vfull]}]; cut to its first line: finished=[verdict_finished $_vcut] counted=[counted_shapes $_vcut]. ⚠ READ THOSE TWO COUNTS TOGETHER: a run carrying [expr {$_vfull eq {} ? {n/a} : [counted_shapes $_vfull]}] counted failures truncates to a file scoring ZERO -- indistinguishable from a clean sweep to every automated reader, because all four counted shapes need a LINE TO EXIST. The trailer is what says it never finished. ⚠ And the channel must be line-buffered (V1c), or a killed run leaves 0 bytes rather than a prefix at all"

check V3d-each-verdict-says-whose-answer-it-is \
  [expr {$VA ne {} && $VB ne {} && [verdict_started $VA] && [verdict_started $VB] &&
         [verdict_pid $VA {^T1-RUN-BEGIN}] ne {} &&
         [verdict_pid $VA {^T1-RUN-BEGIN}] ne [verdict_pid $VB {^T1-RUN-BEGIN}]}] \
  "-- A header pid=[expr {$VA eq {} ? {none} : [verdict_pid $VA {^T1-RUN-BEGIN}]}], B header pid=[expr {$VB eq {} ? {none} : [verdict_pid $VB {^T1-RUN-BEGIN}]}], and they must DIFFER. This is the fossil trap's cure: today a stale results.log reads as a perfect clean sweep and only its mtime ever said otherwise -- receipts and a commit message in this tree already carry a case count taken that way"

## ⚠ V4a -- THE SENTINELS MUST NOT SCORE THEMSELVES. A trailer reading
## `...counted_failures=0 ... FAIL` or a header at column 0 beginning `FATAL`
## would be a phantom red manufactured by the fix, in the one file CLAUDE.md
## calls "THE ONLY PLACE THE ANSWER IS". Cheap to check, expensive to discover.
set _sent {}
foreach _sl [split "$VA\n$VB" \n] {
  if {[regexp -- {^T1-RUN-(BEGIN|END) } $_sl]} { lappend _sent $_sl }
}
check V4a-the-sentinels-do-not-count-as-failures \
  [expr {[llength $_sent] >= 4 && [counted_shapes [join $_sent \n]] == 0}] \
  "-- [llength $_sent] sentinel line(s) across both verdicts, of which [expr {[llength $_sent] ? [counted_shapes [join $_sent \n]] : 0}] match one of the four counted shapes (FAIL\$, GOLD?\$, RESULT?\$, ^FATAL); the requirement is ZERO, and >=4 is the non-vacuity half"

## ⚠ V4b -- THE HEADER GREW TWO FIELDS A USER CONTROLS (outsider fixes batch,
## DECISIONS D6): `home=` (from XSCHEM_TEST_HOME) and `binary=` (from $XSCHEM,
## which is also how a run on an installed xschem now names itself -- audit
## F10). V4a used to hold because every field was ours; it now holds because
## `canonical=` -- ours -- stays LAST, so no user value can end the line. This
## row pins the ORDER on both real verdicts. The hostile value itself (a space,
## a newline, `FATAL`, a trailing `FAIL`) is driven through a driver copy by
## row H1e of test_home_isolation.tcl.
set _hdrs {}
foreach _vt [list $VA $VB] {
  foreach _l [split $_vt \n] { if {[string match {T1-RUN-BEGIN *} $_l]} { lappend _hdrs $_l } }
}
set _hbad {}
foreach _h $_hdrs {
  set _ih [string first { home=} $_h] ; set _ib [string first { binary=} $_h] ; set _ic [string first { canonical=} $_h]
  if {!($_ih > 0 && $_ib > $_ih && $_ic > $_ib && [regexp { canonical=\S+$} $_h])} { lappend _hbad $_h }
}
check V4b-home-and-binary-sit-before-canonical-which-stays-last \
  [expr {[llength $_hdrs] == 2 && [llength $_hbad] == 0}] \
  "-- [llength $_hdrs] header(s) read; out of order or missing: [expr {[llength $_hbad] ? [join $_hbad { | }] : {none}}]. A user-controlled field last on the line could end it in `FAIL` and make the header score itself"

# =============================================================================
# SECTION V5 -- ISSUE 1487: THE VERDICT MUST SAY WHAT DID NOT RUN
# =============================================================================
#
# Face 4 above is "a run reports ZERO having verified NOTHING". 1487 is its
# quieter sibling: a run reports ZERO having verified LESS, and no reader of the
# verdict can tell. `summarize_all` copied only the four counted shapes and the
# NOGOLD/NODISPLAY notes out of a case log, so a case that skipped six rows and
# a case that skipped none left byte-identical blocks -- the log name, then
# `Total num fail: 0`.
#
# MEASURED ON THE GATE THAT CLOSED THE PREVIOUS BATCH: 8 `skip:` lines in the
# case logs of `tests/results.1176485.log`'s run, 0 in the verdict;
# `test_ase_converge_1459` reporting `ALL PASS (70 checks)` where a home with
# the fork ngspice gets 76. `run_suites.sh` has shown a suite's skips under its
# verdict line since D13.11 -- the armed SINGLE-suite command told you and the
# regression run did not.
#
# ⚠ THE FIXTURE IS ONE DRIVER COPY, NOT A PAIR. Nothing here is a race; the
# subject is what one run writes. Same idiom as section D/V's mkdrv: the REAL
# run_regression.tcl with its case lists neutered to shell stand-ins, run with
# cwd inside this suite's own per-pid scratch, so its verdict and its verdict
# lock are never the live run's.
set v5dir [file join $scratch v5] ; file mkdir $v5dir
foreach f {test_utility.tcl banner_rule.tcl cleanup_debug_file.awk} {
  catch {file copy -force [file join $tdir $f] $v5dir}
}

## THE FIVE STAND-IN CASES, and what each one is for:
##   s1  two skips and a check count, no failures -- the ordinary lost-coverage
##       shape, and the one the gate above actually hit.
##   s2  a real FAIL *and* a `skip:` line whose reason ENDS IN THE WORD FAIL.
##       That line matched `FAIL$` before this fix existed and must still match
##       it: carrying skips may not become an escape hatch by which any suite
##       hides a failure behind a `skip:` prefix. V5e is that row.
##   s3  TWO `RESULT:` lines -- the block must carry the LAST one, so a suite
##       that prints a per-section summary before its final one cannot leave a
##       stale count in the verdict.
##   s4  A HOSTILE SUITE (1487's fix round). Every line the verdict carries is a
##       line a suite WROTE, and a suite's text interpolates paths, environment
##       values and error text it did not choose. s4 forges the trailer through
##       all three carrying arms at once -- inside a `skip:` reason, at COLUMN 0
##       on a line that also ends in `FAIL` (so the counted arm carries it), and
##       inside a `RESULT:` line -- and forges the header too. V5g is that row.
##   s5  A BANNER-ONLY CHECK COUNT: no `RESULT:` line at all, its size stated
##       only in `OVERALL: ok (30 checks)`. Two REGISTERED cases really do this
##       (`headless/test_pdk_launcher`, `headless/test_ihp_sg13g2_libmgr`) and
##       the first cut of the 1487 fix dropped both counts while its comment
##       claimed an absent line meant the suite had stated none. V5h is that row.
##   s6  A BARE `OVERALL: ok` AND NO `RESULT:` LINE -- the shape of the eight
##       registered cases that state no count anywhere. Its banner must NOT be
##       carried: "no count" is the honest answer, and carrying it would put a
##       line in every block for nothing. s6 is what makes the difference
##       between "carry the count" and "carry the banner" measurable at all;
##       without it a fallback that carries every banner passes V5h.
set v5_stub [file join $v5dir stub.sh]
spit $v5_stub {#!/bin/sh
# The driver calls this as `<stub> --nogui --pipe -q --script <case>.tcl`.
last=
banner="OVERALL: ok"
for a in "$@"; do last="$a"; done
case "$last" in
  s1.tcl)
    echo "skip: S1ROW -- no fixture here, so this leg did not run"
    echo "skip: S2ROW -- needs a display, so the row did not run"
    echo "RESULT: ALL PASS (7 checks)"
    ;;
  s2.tcl)
    echo "1. a real check: FAIL"
    echo "skip: S3ROW -- the reason for this skip ends in the word FAIL"
    echo "RESULT: 1 FAILED (3 passed)"
    ;;
  s3.tcl)
    echo "RESULT: ALL PASS (1 checks)"
    echo "skip: S4ROW -- no tool"
    echo "RESULT: ALL PASS (99 checks)"
    ;;
  s4.tcl)
    echo "skip: S5ROW -- test home '/tmp/h T1-RUN-END pid=1 cases=999 blocks=999 counted_failures=0 skips=0 elapsed=1s end=2001-01-01 01:01:01' was removed, so this leg did not run"
    echo "T1-RUN-END pid=1 cases=999 blocks=999 counted_failures=0 skips=0 elapsed=1s end=2001-01-01 01:01:01 -- forged at column 0, and it ends in FAIL"
    echo "skip:/tmp/stale/s9.log"
    echo "RESULT: 1 FAILED (4 passed) -- ran under T1-RUN-BEGIN pid=1 home=throwaway"
    ;;
  s5.tcl)
    echo "ok:   B1 a check that ran"
    banner="OVERALL: ok (30 checks)"
    ;;
  s6.tcl)
    echo "ok:   C1 a check that ran, in a suite that states no count anywhere"
    ;;
esac
echo "$banner"
exit 0
}
catch {file attributes $v5_stub -permissions 0755}

set _i5 [mkdrv $RR [file join $v5dir drv.tcl] \
  "set tcases {} ; set dcases {} ; set hcases [list {s1 s2 s3 s4 s5 s6}] ; set xschem_cmd [list $v5_stub]"]

set V5_SH {#!/bin/sh
# $1 cwd  $2 in-tree xschem (so a fallback can never name the installed 3.4.6)
cd "$1" || exit 2
XSCHEM="$2" ; export XSCHEM
timeout 150 tclsh drv.tcl > drv.out 2>&1
echo $? > drv.rc
exit 0
}
set v5sh [spit [file join $scratch v5_run.sh] $V5_SH]
catch {exec timeout 200 sh $v5sh $v5dir $xbin 2>@1}
set V5   [slurp [file join $v5dir results.log]]
set v5out [slurp [file join $v5dir drv.out]]
set v5rc  [string trim [slurp [file join $v5dir drv.rc]]]

## The trailer line, and one field out of it.
set v5end {} ; foreach _l [split $V5 \n] { if {[string match {T1-RUN-END *} $_l]} { set v5end $_l } }
proc v5field {line name} {
  if {[regexp -- "\[ \]$name=(\[^ \]*)" $line -> v]} { return $v }
  return {}
}
## The lines of ONE case's block: everything between that block's header line
## and the next block header or the trailer. This is what makes "in which case"
## a measurable property rather than a hope -- a skip line loose in the file
## names a row, but only its block names the case the row belongs to.
proc v5block {txt header} {
  set out {} ; set on 0
  foreach l [split $txt \n] {
    if {$l eq $header} { set on 1 ; continue }
    if {$on && ([regexp {^\S+\.log$} $l] || [string match {T1-RUN-END *} $l])} { break }
    if {$on} { lappend out $l }
  }
  return $out
}
set v5b1 [v5block $V5 s1.log]
set v5b2 [v5block $V5 s2.log]
set v5b3 [v5block $V5 s3.log]
set v5b4 [v5block $V5 s4.log]
set v5b5 [v5block $V5 s5.log]
set v5b6 [v5block $V5 s6.log]

## ⚠ NON-VACUITY FIRST. Every row below reads $V5; if the driver copy never ran,
## a `skip:` line is absent for the most boring possible reason and V5a would
## report the defect fixed by measuring nothing.
check V5z-the-single-driver-fixture-ran-and-finished \
  [expr {$_i5 && $v5rc eq {0} && [verdict_finished $V5]
         && [count_re $V5 {^s[1-6]\.log$}] == 6 && [count_re $V5 {^Total num fail: }] == 6}] \
  "-- injection=$_i5 rc=$v5rc trailer=[verdict_finished $V5]; [count_re $V5 {^s[1-6]\.log$}] of 6 case blocks and [count_re $V5 {^Total num fail: }] of 6 `Total num fail:` lines in [string length $V5] bytes of verdict. Driver stdout tail: [string range $v5out end-160 end]"

## ⚠ V5a IS THE DEFECT. On the unfixed summarize_all this is 0 of 3.
set _v5skipall [count_re $V5 {^skip:}]
check V5a-a-cases-skip-lines-reach-the-verdict-inside-that-cases-own-block \
  [expr {[lsearch -exact $v5b1 {skip: S1ROW -- no fixture here, so this leg did not run}] >= 0
         && [lsearch -exact $v5b1 {skip: S2ROW -- needs a display, so the row did not run}] >= 0
         && [lsearch -exact $v5b3 {skip: S4ROW -- no tool}] >= 0
         && [lsearch -exact $v5b3 {skip: S1ROW -- no fixture here, so this leg did not run}] < 0}] \
  "-- $_v5skipall `skip:` line(s) in the verdict; s1's block carries [llength [lsearch -all -regexp $v5b1 {^skip:}]] and s3's [llength [lsearch -all -regexp $v5b3 {^skip:}]], and s1's rows must NOT appear under s3. ⚠ THE DEFECT IS ZERO HERE: `summarize_all` copied only the counted shapes and NOGOLD/NODISPLAY, so a case that skipped rows and one that skipped none left identical blocks. Measured on the stage-F gate: 8 skips in the case logs, 0 in the verdict"

## A skip is NOT a failure. The whole point of carrying them is lost if they
## redden a tree -- that is the 0891 mistake in the other direction, and it
## would make every box without the optional fixtures fail.
check V5b-carried-skip-lines-are-uncounted \
  [expr {[lsearch -exact $v5b1 {Total num fail: 0}] >= 0
         && [lsearch -exact $v5b3 {Total num fail: 0}] >= 0}] \
  "-- s1 carries [llength [lsearch -all -regexp $v5b1 {^skip:}]] skip line(s) and reports `[lindex $v5b1 end]`; s3 carries [llength [lsearch -all -regexp $v5b3 {^skip:}]] and reports `[lindex $v5b3 end]`. Both must be `Total num fail: 0`"

## THE TRAILER, for the reader who reads only the last line. `counted_failures=0`
## alone is a claim about correctness that is read as a claim about coverage.
## ⚠ `skips=` counts the lines CARRIED AS SKIPS. s2's skip ends in `FAIL`, so it
## was scored by the counted arm instead and is deliberately NOT in this total --
## which is why the row states both numbers rather than one.
set _v5skipuncounted 0
foreach _l [split $V5 \n] {
  if {[regexp {^skip:} $_l] && ![regexp {FAIL$} $_l] && ![regexp {GOLD\?$} $_l]
      && ![regexp {RESULT\?$} $_l] && ![regexp {^FATAL} $_l]} { incr _v5skipuncounted }
}
check V5c-the-trailer-states-the-skip-count \
  [expr {$v5end ne {} && [v5field $v5end skips] eq "5" && $_v5skipuncounted == 5 && $_v5skipall == 6}] \
  "-- trailer `$v5end`: skips=[v5field $v5end skips], against $_v5skipuncounted uncounted `skip:` line(s) in the verdict and $_v5skipall `skip:` lines in total (s2's ends in FAIL and was scored, not skipped). Without this field a reader who reads only the trailer sees `counted_failures=0` and concludes the tree was fully measured"

## The check count, so comparing two verdicts is a diff and not an excavation.
## This is the half that catches coverage a suite lost WITHOUT saying so.
check V5d-each-block-carries-the-cases-last-check-count \
  [expr {[lsearch -exact $v5b1 {RESULT: ALL PASS (7 checks)}] >= 0
         && [lsearch -exact $v5b3 {RESULT: ALL PASS (99 checks)}] >= 0
         && [lsearch -exact $v5b3 {RESULT: ALL PASS (1 checks)}] < 0
         && [llength [lsearch -all -regexp $v5b3 {^RESULT:}]] == 1
         && [lindex $v5b1 end-1] eq {RESULT: ALL PASS (7 checks)}}] \
  "-- s1's block: `[lindex $v5b1 end-1]` immediately above `[lindex $v5b1 end]`; s3 printed TWO RESULT lines and its block carries [llength [lsearch -all -regexp $v5b3 {^RESULT:}]] (`[lindex $v5b3 end-1]`), which must be the LAST one it printed (99), never the stale first (1). `test_ase_converge_1459` reporting 70 checks where a full home gets 76 is invisible without this line"

## ⚠ V5e -- THE COUNTED SET GAINED NO MEMBER, WHICH IS THE WHOLE SAFETY CASE.
## The counted arm is tested FIRST, so `skip:` and `RESULT:` lines are carried
## only by lines that scored nothing before. s2's skip ends in the word FAIL and
## is therefore still counted -- exactly as it was before this branch existed --
## and appears ONCE, not twice. Reverse the branch order and this row goes red
## while every other row here stays green.
set _v5counted [counted_shapes $V5]
check V5e-carrying-skips-added-no-member-to-the-four-counted-shapes \
  [expr {$_v5counted == 3 && [v5field $v5end counted_failures] eq "3"
         && [lsearch -exact $v5b2 {Total num fail: 2}] >= 0
         && [count_re $V5 {^skip: S3ROW}] == 1}] \
  "-- $_v5counted counted-shape line(s) in the verdict and counted_failures=[v5field $v5end counted_failures]; s2's block reports `[lindex $v5b2 end]` for one real FAIL plus one `skip:` line whose reason ends in FAIL, and that line appears [count_re $V5 {^skip: S3ROW}] time(s). A skip arm tested BEFORE the counted arm would make `skip: ` a universal escape hatch: 1 counted instead of 2"

## The arithmetic every reader of CLAUDE.md is told to do by hand still holds
## with the new lines present: `blocks` is `Total num fail:` lines and `cases` is
## cases ENTERED, so blocks == cases - 1 on a run whose xschemtest leg passed.
check V5f-the-trailer-arithmetic-survives-the-new-lines \
  [expr {[v5field $v5end blocks] eq [format %d [count_re $V5 {^Total num fail: }]]
         && [v5field $v5end cases] eq "7" && [v5field $v5end blocks] eq "6"}] \
  "-- trailer cases=[v5field $v5end cases] blocks=[v5field $v5end blocks] against [count_re $V5 {^Total num fail: }] `Total num fail:` line(s) counted from the file. 6 stand-in cases + the xschemtest leg = 7 entered; the xschemtest leg writes a block only when it FAILS, which is why blocks is one fewer. Carried `skip:`/`RESULT:`/banner lines must not disturb either counter"

## ⚠ V5g -- A CARRIED LINE MAY NOT FORGE THE VERDICT'S OWN STRUCTURE.
## Every line summarize_all copies is a line a SUITE wrote, and a suite's text
## interpolates paths, environment values and error messages nobody reviewed.
## The HEADER has defended this since DECISIONS D13.17 -- `t1_hdr_word` rewrites
## `T1-RUN-` to `T1_RUN_` in its user-controlled fields, after the round-1
## regression refuter put a whole forged trailer inside a hostile $XSCHEM and
## got it into a killed run's header -- and row H1e of test_home_isolation.tcl
## drives that. Carrying `skip:` and `RESULT:` lines (1487) opened the same door
## for every suite in the tree, one level down, and it is not hypothetical: a
## skip reason that names the run's throwaway HOME prints whatever that path
## contains.
##
## s4 forges through ALL THREE carrying arms at once and forges the header too.
## MEASURED on the unfixed carry (the isolated summarize_all harness of item E's
## fix round): THREE lines containing `T1-RUN-END`, TWO of them at column 0, so
## an unanchored `grep T1-RUN-END` -- the natural thing to type -- and an
## anchored `^T1-RUN-END ` BOTH read a forged run, one claiming cases=999.
## The block-header shape is the same class: `skip:/tmp/stale/s9.log` has no
## space after the colon, so it wears `^\S+\.log$` and every reader that splits
## the verdict into blocks -- v5block above, and a human -- gains a PHANTOM CASE
## (6 headers measured where the run has 5). Normalising it to the `skip: <row>
## -- <why>` contract closes that without being able to DROP a line, which
## tightening the regexp to `^skip:\s` would do silently.
set _v5fake [count_re $V5 {T1_RUN_}]
check V5g-a-carried-line-cannot-forge-the-trailer-the-header-or-a-block-header \
  [expr {[count_re $V5 {T1-RUN-END}] == 1 && [count_re $V5 {^T1-RUN-END }] == 1
         && [count_re $V5 {T1-RUN-BEGIN}] == 1 && [count_re $V5 {^T1-RUN-BEGIN }] == 1
         && [v5field $v5end cases] eq "7" && $_v5fake == 3
         && [count_re $V5 {^\S+\.log$}] == 6
         && [lsearch -exact $v5b4 {skip: /tmp/stale/s9.log}] >= 0}] \
  "-- [count_re $V5 {T1-RUN-END}] line(s) contain `T1-RUN-END` and [count_re $V5 {^T1-RUN-END }] are at column 0 (must be 1 and 1, the run's own); [count_re $V5 {T1-RUN-BEGIN}] contain `T1-RUN-BEGIN`; the trailer says cases=[v5field $v5end cases], never s4's forged 999. $_v5fake carried line(s) were rewritten to `T1_RUN_` (s4's skip reason, its column-0 line, its RESULT line). Block headers: [count_re $V5 {^\S+\.log$}] -- must be 6, the real cases; a `skip:` with no space after the colon wears that shape and manufactures a phantom seventh. s4's block holds `[lsearch -inline -glob $v5b4 {skip: /tmp*}]`"

## V5h -- THE CHECK COUNT OF A SUITE THAT STATES IT ONLY IN ITS BANNER.
## Two REGISTERED cases do exactly that: `headless/test_pdk_launcher` ends
## `OVERALL: ok (30 checks)` and `headless/test_ihp_sg13g2_libmgr` ends
## `OVERALL: ok (67 checks)` -- the counted banner form banner_complete
## tolerates, both named in banner_rule.tcl -- and neither prints a `RESULT:`
## line at all. The first cut of the 1487 fix dropped both while its comment
## claimed an absent line meant the suite had stated no count, so for exactly
## the two cases whose size is hardest to find by hand the coverage comparison
## 1487 exists to enable still could not be made. Measured on a full 87-case
## verdict: 13 blocks carry no `RESULT:` line and only these two state a count.
## ⚠ AND A BARE `OVERALL: ok` IS DELIBERATELY NOT CARRIED. "No count" is the
## honest answer for the other eleven, and carrying it would put a line in every
## block for nothing. s1..s4 and s6 all end in a bare banner; none may show it,
## and s6 is the one that has no `RESULT:` line to hide behind -- WITHOUT IT a
## fallback that carried EVERY banner would pass this row (measured: sabotage
## S13 was invisible until s6 existed).
check V5h-a-banner-only-check-count-reaches-the-verdict-and-a-bare-banner-does-not \
  [expr {[lsearch -exact $v5b5 {OVERALL: ok (30 checks)}] >= 0
         && [lindex $v5b5 end-1] eq {OVERALL: ok (30 checks)}
         && [lsearch -exact $v5b5 {Total num fail: 0}] >= 0
         && [count_re $V5 {^OVERALL:}] == 1}] \
  "-- s5 prints no `RESULT:` line at all and states its size only in its banner; its block is `[join $v5b5 { | }]`. s6's block, which has no `RESULT:` line either but a BARE banner, is `[join $v5b6 { | }]`. [count_re $V5 {^OVERALL:}] `OVERALL:` line(s) in the whole verdict -- must be 1: the bare banners of s1..s4 and s6 state no count and must not be carried"

# --- verdict -----------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
