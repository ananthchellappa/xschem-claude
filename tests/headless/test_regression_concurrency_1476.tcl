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
# ⚠ FLOOR: 20 checks, and it only ever goes up. 13 were RED when this suite was
# written, and 7 were the non-vacuity and guard rows that had to be green from
# the start; ALL 20 are green as of the B1 and C1 fixes, so a red one now is a
# REGRESSION rather than an unfixed face (V1b is the one that reds if
# `results.log` is ever renamed, which ruling R1 forbids).
#
#   headless -> 20 checks
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
# SECTION V -- the verdict file (face 4)
# =============================================================================

## V1b is a GUARD, green today and required by ruling R1 to stay green: the
## canonical name is read by doc/claude/ledger/crew.js, by CLAUDE.md's own
## reading instructions and by the user. If C1 is ever overturned in favour of
## `results.<pid>.log`, this row is what says so out loud.
check V1b-the-verdict-keeps-its-canonical-name \
  [expr {[regexp -line {^[ \t]*set[ \t]+log_fn[ \t]+\"results\.log\"[ \t]*$} $RR] ? 1 : 0}] \
  "-- run_regression.tcl says `[string trim [src_line $RR {^[ \t]*set[ \t]+log_fn[ \t]}]]`; ruling R1: the scratch dir is per-run, the VERDICT is serialised under its own name, and renaming it would break every reader that names it"

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
set _ablocks [count_re $verdict {^a[1-4]\.log$}]
set _bblocks [count_re $verdict {^b1\.log$}]
## Any wording C1 might choose for "I did not take the verdict file".
set _announced [regexp -nocase {lock|wait|refus|already running|in use|another run} $f4Bout]

check V0a-both-driver-copies-were-built [expr {$_iA && $_iB && $frc != 124}] \
  "-- injection A=$_iA B=$_iB, pair rc=$frc; without both, V2a and V2b measure nothing"
check V2b-the-first-run-verdict-is-complete [expr {$_ablocks == [llength $F4_A_CASES]}] \
  "-- $_ablocks of [llength $F4_A_CASES] case blocks, [string length $verdict] bytes; the non-vacuity half, and the reason face 4 is SILENT rather than loud -- when it strikes nothing is corrupted, the surviving verdict is perfectly well-formed, and only the OTHER run's answer is missing"
check V2a-the-second-run-verdict-is-not-silently-discarded \
  [expr {$_bblocks > 0 || $_announced}] \
  "-- b1 blocks in the verdict=$_bblocks, announced=$_announced, B rc=[string trim [slurp [file join $fdir B.rc]]]; B said: `[string trim [src_line $f4Bout {(?i)lock|wait|refus|already running|in use|another run}]]`. With NEITHER a block nor an announcement, a whole run reports success and its verdict never existed"

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
