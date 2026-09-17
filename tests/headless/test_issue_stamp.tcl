## File: tests/headless/test_issue_stamp.tcl
##
## RED-FIRST regression for the ISSUE-STAMP checker (tests/headless/issue_stamp.tcl).
## Spec: doc/claude/specs/issue_stamp.md
##
## WHY THIS SUITE EXISTS AND NOT JUST THE CHECKER.  There are ZERO stamped files
## in doc/claude/issues/ today, so every forward check in the gate has an empty
## input set.  A gate like that prints a green while doing nothing whatsoever --
## which is the exact family of failure this whole batch is about: five driver
## measurements in one evening, every one a command that returned a plausible
## number without doing what was meant (a grep that swallowed its own pattern and
## counted 1050 files in a corpus of 1047; a regex that read a MemTotal in kB as
## a git SHA; a line-oriented grep that missed a phrase because markdown
## hard-wraps it).  The rule those errors bought is that every mechanical check
## is run first against a case whose answer is already KNOWN.  This file is that
## set of known answers, and the gate refuses to report a verdict without it.
##
## HOW TO RUN IT
##     tclsh tests/headless/test_issue_stamp.tcl
##     ./src/xschem --nogui --pipe -q --script tests/headless/test_issue_stamp.tcl
##     tests/headless/run_suites.sh test_issue_stamp
## It needs no display, no simulator, no built binary and no T1 run.
##
## AUTHORING CONSTRAINT, inherited from test_audit_classifier.tcl: the fixture
## text contains the very tokens under test.  Fixtures live in Tcl variables and
## are never echoed at column 0, because full_audit.sh classifies a whole suite
## from unanchored substrings of its output.

set ::ISSUE_STAMP_LIB 1
source [file join [file dirname [info script]] issue_stamp.tcl]
istamp::init

set npass 0
set fail  0

proc check {name got want} {
    global npass fail
    if {$got eq $want} {
        incr npass
        puts "ok:   $name"
    } else {
        incr fail
        puts "      got:  $got"
        puts "      want: $want"
        puts "$name : FAIL"
    }
}

## Run `body` with the checker pointed at a throw-away corpus instead of the real
## one.  `repo` is deliberately left alone: git must still resolve revisions
## against the real repository, because the point of a stamp is that the
## revision it names is findable HERE.
proc with_corpus {issuesdir baselinefile body} {
    set o1 $istamp::issues_dir
    set o2 $istamp::baseline
    set istamp::issues_dir $issuesdir
    set istamp::baseline   $baselinefile
    set rc [catch {uplevel 1 $body} res opt]
    set istamp::issues_dir $o1
    set istamp::baseline   $o2
    if {$rc} { return -options $opt $res }
    return $res
}

proc mkcorpus {tag files {baseline ""}} {
    set d [file join [file dirname [file normalize [info script]]] .scratch \
                     istamp_[pid]_$tag]
    file delete -force $d
    file mkdir [file join $d issues]
    foreach {name body} $files {
        set fh [open [file join $d issues $name] w]
        fconfigure $fh -encoding utf-8
        puts $fh $body
        close $fh
    }
    set bf [file join $d baseline.txt]
    set fh [open $bf w]
    puts $fh $baseline
    close $fh
    return [list [file join $d issues] $bf]
}

## How many gate problems mention this substring?
proc problems_matching {issuesdir baselinefile needle} {
    set n 0
    foreach p [with_corpus $issuesdir $baselinefile {istamp::gate}] {
        if {[string first $needle $p] >= 0} { incr n }
    }
    return $n
}

set REV [string trim [exec timeout 30 git -C $istamp::repo rev-parse --short=8 HEAD]]

puts "## issue-stamp checker, corpus [file tail $istamp::issues_dir], tree $REV"

## ---------------------------------------------------------------------------
## S -- the grammar.  Half of these are the ONLY reason a green from the gate
## means anything, because the real corpus exercises none of them yet.
## ---------------------------------------------------------------------------

check "S1 a well-formed stamp parses and yields its fields" \
    [set r [istamp::parse_stamp \
        {**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=3`}] ;
     list [dict get $r ok] [dict get [dict get $r f] claim] [dict get [dict get $r f] open]] \
    {1 open 3}

check "S2 every claim word in the vocabulary is accepted" \
    [set out {} ; foreach c {open fixed partial latent wontfix} {
        lappend out [dict get [istamp::parse_stamp \
            "**STAMP:** `v1 claim=$c tree=d64686a1 stamped=2026-09-17 fix=none open=0`"] ok]
     } ; set out] \
    {1 1 1 1 1}

## ⚠ A ONE-BIT STATUS CANNOT EXPRESS THIS CORPUS, which is why `partial` and
## `latent` are in the vocabulary and why `open=` is a COUNT and not a flag.
## Issue 0905 needs four answers at once (subject fixed, section 1 stale,
## section 2 stale AND INVERTED -- it records as "deliberately rejected" the
## very shape the tree now runs -- and section 3 half done).  0891 needs "2 of 3
## follow-ups landed".  0890 and 1219 need "claims latent, is actually live",
## the direction a reader never re-checks because a file admitting weakness
## reads as honest.  A header that forces FIXED-or-OPEN rounds all four wrong.
check "S3 partial + a nonzero outstanding count expresses 0891's 2-of-3 shape" \
    [set r [istamp::parse_stamp \
        {**STAMP:** `v1 claim=partial tree=aa0e2213 stamped=2026-09-17 fix=partial open=1 by=A3`}] ;
     list [dict get $r ok] [dict get [dict get $r f] claim] [dict get [dict get $r f] open] \
          [dict get [dict get $r f] by]] \
    {1 partial 1 A3}

check "S4 latent is a first-class claim (0890, 1219: says latent, is live)" \
    [dict get [istamp::parse_stamp \
        {**STAMP:** `v1 claim=latent tree=43b40f04 stamped=2026-09-17 fix=untried open=2`}] ok] \
    1

check "S5 no version token is rejected" \
    [dict get [istamp::parse_stamp \
        {**STAMP:** `claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=0`}] ok] \
    0

check "S6 a missing required key is rejected" \
    [dict get [istamp::parse_stamp \
        {**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none`}] ok] \
    0

check "S7 a claim word outside the vocabulary is rejected" \
    [dict get [istamp::parse_stamp \
        {**STAMP:** `v1 claim=maybe tree=d64686a1 stamped=2026-09-17 fix=none open=0`}] ok] \
    0

## ⚠ THIS ROW IS DRIVER ERROR 5, MECHANISED.  A bare [0-9a-f]{8,40} matches any
## 8-digit DECIMAL, so a census of "cited SHAs that do not resolve" was led by
## 16091816 -- the box's MemTotal in kB -- and by 141592654, which is pi.  A
## revision token must contain at least one a-f.
check "S8 a decimal that is not a revision is rejected as tree=" \
    [list [dict get [istamp::parse_stamp \
             {**STAMP:** `v1 claim=open tree=16091816 stamped=2026-09-17 fix=none open=0`}] ok] \
          [dict get [istamp::parse_stamp \
             {**STAMP:** `v1 claim=open tree=141592654 stamped=2026-09-17 fix=none open=0`}] ok]] \
    {0 0}

check "S9 a non-ISO date is rejected" \
    [dict get [istamp::parse_stamp \
        {**STAMP:** `v1 claim=open tree=d64686a1 stamped=17-09-2026 fix=none open=0`}] ok] \
    0

## ⚠ THE 0442 RULE.  0442's numbered item 1 was ACCURATE WHEN WRITTEN; the tree
## then fixed the defect by the unnumbered alternative at the end of the same
## section, and pasting item 1 today re-introduces what was deliberately
## deleted.  No status field catches that -- the status was never wrong.  Only
## "which option was taken, and what replaced the one that wasn't" catches it.
check "S10 fix=superseded must name its replacement (the 0442 rule)" \
    [list [dict get [istamp::parse_stamp \
             {**STAMP:** `v1 claim=fixed tree=d64686a1 stamped=2026-09-17 fix=superseded open=0`}] ok] \
          [dict get [istamp::parse_stamp \
             {**STAMP:** `v1 claim=fixed tree=d64686a1 stamped=2026-09-17 fix=superseded open=0 super=0437`}] ok]] \
    {0 1}

check "S11 claim=duplicate must name the survivor (1458 cited 1397 and duplicated it anyway)" \
    [list [dict get [istamp::parse_stamp \
             {**STAMP:** `v1 claim=duplicate tree=d64686a1 stamped=2026-09-17 fix=none open=0`}] ok] \
          [dict get [istamp::parse_stamp \
             {**STAMP:** `v1 claim=duplicate tree=d64686a1 stamped=2026-09-17 fix=none open=0 super=1397`}] ok]] \
    {0 1}

check "S12 a typo'd key is rejected, never silently ignored" \
    [dict get [istamp::parse_stamp \
        {**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=0 clam=x`}] ok] \
    0

check "S13 a duplicated key is rejected" \
    [dict get [istamp::parse_stamp \
        {**STAMP:** `v1 claim=open claim=fixed tree=d64686a1 stamped=2026-09-17 fix=none open=0`}] ok] \
    0

check "S14 an ordinary prose status line is not a stamp" \
    [list [dict get [istamp::parse_stamp {Status: OPEN -- measured 2026-08-22}] ok] \
          [dict get [istamp::parse_stamp {**Status:** FIXED 2026-08-29}] ok]] \
    {0 0}

check "S15 the formatter and the parser agree (one writer, one reader)" \
    [dict get [istamp::parse_stamp [istamp::format_stamp \
        [dict create claim fixed tree $REV stamped 2026-09-17 fix taken open 0]]] ok] \
    1

## ⚠ THIS ROW WAS RED WHEN IT WAS WRITTEN, and it is the reason find_stamp is a
## regexp and not a `string match`.  In a glob pattern the stamp's own leading
## `**` are two WILDCARDS, so `string match {**STAMP:** *}` matches any line that
## merely MENTIONS the token -- including a comment ABOUT the convention.  A
## pattern that matches itself is how `pgrep -af run_regression` came to answer
## four hits for one run, and how a `grep -lieE` came to answer 1050 for 1047.
check "S16 a line that merely mentions the token mid-sentence is not a stamp" \
    [dict get [istamp::find_stamp \
        "# see **STAMP:** `v1 ...` in the spec\nnothing here\n"] n] \
    0

check "S17 the stamp is found when it is genuinely at column 0" \
    [set r [istamp::find_stamp \
        "# 0001 - title\n\n**STAMP:** `v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=0`\n"] ;
     list [dict get $r n] [dict get $r lineno]] \
    {1 3}

check "S18 two stamps in one file are detected (two headers is the both-words defect in miniature)" \
    [dict get [istamp::find_stamp \
        "**STAMP:** `v1 a`\nx\n**STAMP:** `v1 b`\n"] n] \
    2

## ---------------------------------------------------------------------------
## B -- the baseline is IDENTITY, not a count
## ---------------------------------------------------------------------------

## ⚠ THE WORKED EXAMPLE REFUTED THE FIRST GRAMMAR, which required super= to be a
## 4-digit issue number.  0442 -- the case fix=superseded was invented for -- was
## superseded by an UNNUMBERED alternative at the end of its own fix section, so
## there is no number to name.  A grammar that cannot express its own motivating
## example gets worked around instead of used.
check "S19 super= takes an issue number, a revision, or self (0442 has no number to name)" \
    [set out {} ; foreach s {0437 32dff39a self} {
        lappend out [dict get [istamp::parse_stamp \
            "**STAMP:** `v1 claim=fixed tree=d64686a1 stamped=2026-09-17 fix=superseded open=0 super=$s`"] ok]
     } ; lappend out [dict get [istamp::parse_stamp \
            {**STAMP:** `v1 claim=fixed tree=d64686a1 stamped=2026-09-17 fix=superseded open=0 super=itself`}] ok] ;
     set out] \
    {1 1 1 0}

## ⚠ RED WHEN WRITTEN, AND THE SHARPEST ROW IN THIS FILE.  init() used to derive
## the repo from [info script] AT CALL TIME, so any driver script living
## somewhere else resolved the repo two levels above ITSELF.  git -C then pointed
## at a non-repository, every rev_exists() returned false, and a VALID stamp was
## reported as "tree= does not resolve to a commit in this repo".  A plausible
## red from a broken command, produced by the very checker written to catch that
## family -- and caught only because the revision under test was known-good.
## This row runs the checker from a directory that is not tests/headless.
check "S20 the repo is derived from the CHECKER's own location, not the caller's script" \
    [set d [file join [file dirname [file normalize [info script]]] .scratch drv_[pid]] ;
     file mkdir $d ;
     set fh [open [file join $d drv.tcl] w] ;
     puts $fh "set ::ISSUE_STAMP_LIB 1" ;
     puts $fh "source [file join [file dirname [file normalize [info script]]] issue_stamp.tcl]" ;
     puts $fh "istamp::init" ;
     puts $fh "puts \[istamp::rev_exists $REV\]" ;
     puts $fh "puts \[file tail \$istamp::repo\]" ;
     close $fh ;
     set got [split [string trim [exec timeout 60 tclsh [file join $d drv.tcl]]] \n] ;
     file delete -force $d ;
     set got] \
    {1 xschem-claude}

## ⚠ THIS ROW USED TO ASSERT THE BASELINE COVERED EVERY NUMBERED FILE, AND IT
## COULD ONLY STAY GREEN WHILE THE CONVENTION WAS NEVER USED.  Adopting a file is
## exactly "stamp it, then delete its number from the baseline" -- the baseline's
## own header says SHRINK THIS FILE, NEVER GROW IT, and BC1's receipt instructs
## D1 to delete the nine it measured.  So the first adoption reddened the suite
## that was written to protect the adoption: measured by D1 the moment it stamped
## the first ten, `got: 1 {0056 0216 0249 0442 0650 0891 0905 1219 1438 1458}`.
## The row was green only because there were zero stamped files when it was
## written, which is the vacuous-green family this very suite exists to prevent.
## The invariant actually meant is COVERAGE, and it is the one that makes "may
## shrink, never grow" true: every numbered issue file is accounted for by the
## baseline OR by a stamp of its own, and none falls between the two.
check "B1 every numbered issue file is covered -- grandfathered in the baseline OR carrying a stamp" \
    [lassign [istamp::load_baseline] okb base ;
     set uncovered {} ;
     foreach {num fname} [istamp::issue_files] {
        if {[dict exists $base $num]} { continue } ;
        set text [istamp::read_file [file join $istamp::issues_dir $fname]] ;
        if {[dict get [istamp::find_stamp $text] n] == 0} { lappend uncovered $num }
     } ;
     list $okb $uncovered] \
    {1 {}}

check "B2 a corpus with no baseline file REFUSES rather than emitting 1047 false reds" \
    [lassign [mkcorpus norebase {0001-x.md {# 0001 - x}}] id bf ;
     file delete -force $bf ;
     set p [with_corpus $id $bf {istamp::gate}] ;
     list [llength $p] [string match "BASELINE MISSING*" [lindex $p 0]]] \
    {1 1}

## ⚠ THE BASELINE MUST NEVER BE ABLE TO SUPPRESS VALIDATION, and the state this
## row describes is not hypothetical: it is what a half-finished adoption leaves
## behind -- the file stamped, its number not yet deleted from the baseline.  If
## being grandfathered short-circuited the stamped path, a malformed stamp would
## ride in behind a number nobody had got round to removing, and the grammar
## could be bypassed simply by not finishing the job.  KNOWN NEGATIVE: the stamp
## below is bad on the 0442 rule (fix=superseded naming nothing) while 0001 IS
## listed in the baseline, so a green here would be the bypass, not a pass.
check "B3 a number still in the baseline does NOT suppress validation of a stamp it carries" \
    [lassign [mkcorpus baseline_no_suppress [list 0001-half-adopted.md "# 0001 - half adopted

**STAMP:** `v1 claim=fixed tree=$REV stamped=2026-09-17 fix=superseded open=0`"] "0001"] id bf ;
     problems_matching $id $bf "must name what replaced it"] \
    1

## ---------------------------------------------------------------------------
## G -- the gate.  RED observed, then GREEN, on each rule.
## ---------------------------------------------------------------------------

check "G1 RED: a NEW issue file with no stamp is refused (the set may shrink, never grow)" \
    [lassign [mkcorpus newnostamp {9999-brand-new-defect.md {# 9999 - a brand new defect

Status: OPEN. Someone filed this today and never stamped it.}} ""] id bf ;
     problems_matching $id $bf "no **STAMP:** line"] \
    1

check "G2 GREEN: the same file with a valid stamp passes" \
    [lassign [mkcorpus newstamped [list 9999-brand-new-defect.md "# 9999 - a brand new defect

**STAMP:** `v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=1`"] ""] id bf ;
     llength [with_corpus $id $bf {istamp::gate}]] \
    0

check "G3 GREEN: a grandfathered unstamped file is not touched" \
    [lassign [mkcorpus grandfathered {0001-old-file.md {# 0001 - an old file

Status: OPEN -- measured 2026-08-22, never stamped.}} "0001"] id bf ;
     llength [with_corpus $id $bf {istamp::gate}]] \
    0

## ⚠ THE FIELD THE WHOLE DESIGN RESTS ON.  Issue 0818 is the one sampled file
## that cited file:line AND named its revision, and `git show fadb226d:` then
## reproduced all four of its dead coordinates EXACTLY -- against 5 of 5 rotted
## for the files that cited bare coordinates.  A tree= that does not resolve
## recovers nothing, so it is the one field worth a hard failure.
check "G4 RED: a tree= that resolves to no commit is refused" \
    [lassign [mkcorpus deadrev {9999-x.md {# 9999 - x

**STAMP:** `v1 claim=open tree=deadbee stamped=2026-09-17 fix=none open=0`}} ""] id bf ;
     problems_matching $id $bf "does not resolve"] \
    1

check "G5 RED: a stamp buried below the header window is refused" \
    [lassign [mkcorpus buried [list 9999-x.md "# 9999 - x\n[string repeat {
} 20]
**STAMP:** `v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=0`"] ""] id bf ;
     problems_matching $id $bf "must be in the first"] \
    1

## ---------------------------------------------------------------------------
## Q -- quoted code.  The class NOTHING else in this project catches.
## ---------------------------------------------------------------------------
##
## A stale line number LOOKS stale the moment you follow it.  A stale quoted
## block still looks like valid C and reads as authoritative.  Issues 0296 and
## 0435 both quote C that no longer exists; A1's phrase for 0435 is "correct by
## reference, damaging by paste".  NEITHER was scored BAD-FIX -- which means the
## count of dangerous stored fixes in this tracker is an undercount.

set real_line [lindex [split [exec timeout 30 git -C $istamp::repo show ${REV}:tests/banner_rule.tcl] \n] 24]

check "Q1 GREEN: a quote that still matches its named revision passes" \
    [lassign [mkcorpus quoteok [list 9999-x.md "# 9999 - x

**STAMP:** `v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=0`

```tcl quote=$REV path=tests/banner_rule.tcl
$real_line
```"] ""] id bf ;
     llength [with_corpus $id $bf {istamp::gate}]] \
    0

check "Q2 RED: a quote that is no longer in its named revision is refused" \
    [lassign [mkcorpus quoterot [list 9999-x.md "# 9999 - x

**STAMP:** `v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=0`

```c quote=$REV path=tests/banner_rule.tcl
Tcl_SetResult(interp, \"xschem set: invalid command.\", TCL_VOLATILE);
```"] ""] id bf ;
     problems_matching $id $bf "is not in"] \
    1

## ---------------------------------------------------------------------------
## A -- declared assertions, and the STALE-FIXED detector
## ---------------------------------------------------------------------------

## ⚠ THIS ROW IS A REAL, LIVE DEFECT IN THIS TREE, NOT A FIXTURE.  Issue 1219's
## subject is that the sabotage protocol's own closing assertion --
##     grep -rn SABOTAGE src/      # must be empty
## -- is NOT empty on a clean tree.  It returns 8 (two sites in ase_window.tcl,
## six in ase.tcl, all prose of the form "A SABOTAGE IS WHY").  A crew running
## it literally must either fail always or wave it through, and 1219 is open.
## The row is GREEN today because the defect is live.  It goes RED the day
## someone fixes 1219 -- which is exactly the event that nothing in this project
## has ever noticed, and the reason 0384/0867/0955/0905/0990 is one defect filed
## five times in seven weeks.
check "A1 1219 is still live: the sabotage protocol's closing check is NOT empty on src/" \
    [lassign [istamp::assert_eval absent SABOTAGE src] holds hits why ;
     list $holds [expr {$hits > 0}] $why] \
    {0 1 {}}

check "A2 RED: a file declaring that assertion HOLDS is refused, because it does not" \
    [lassign [mkcorpus assertholds [list 9999-x.md "# 9999 - x

**STAMP:** `v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=0`

```sh assert=absent pat=SABOTAGE path=src state=holds
grep -rn SABOTAGE src/
```"] ""] id bf ;
     problems_matching $id $bf "states this assertion HOLDS and it does not"] \
    1

check "A3 GREEN: the same file declaring it BROKEN -- which is the truth -- passes" \
    [lassign [mkcorpus assertbroken [list 9999-x.md "# 9999 - x

**STAMP:** `v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=0`

```sh assert=absent pat=SABOTAGE path=src state=broken
grep -rn SABOTAGE src/
```"] ""] id bf ;
     llength [with_corpus $id $bf {istamp::gate}]] \
    0

## ⚠ THE STALE-FIXED DETECTOR, AND THE HIGHEST-VALUE ROW IN THE FILE.
## 7 of 40 sampled files reported finished work as outstanding.  An issue whose
## defect is greppable can DECLARE it -- "this predicate is false today" -- and
## then the checker flags the file the day the predicate becomes true, without
## anybody remembering the issue exists.  Nothing in this project closes an
## issue; this closes the greppable ones.
check "A4 RED: a defect declared BROKEN that now HOLDS is flagged as fixed-but-never-closed" \
    [lassign [mkcorpus assertfixed [list 9999-x.md "# 9999 - x

**STAMP:** `v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=0`

```sh assert=absent pat=ZZQQNOSUCHTOKENZZ path=src state=broken
grep -rn ZZQQNOSUCHTOKENZZ src/
```"] ""] id bf ;
     problems_matching $id $bf "appears FIXED and the issue was never closed"] \
    1

check "A5 an assertion that cannot be evaluated is a named outcome, never a silent pass" \
    [lassign [istamp::assert_eval absent x no/such/path/at/all] holds hits why ;
     list $holds [string match "grep failed*" $why]] \
    {-1 1}

## ---------------------------------------------------------------------------
## N -- ANTI-OVERSHOOT.  Green in both directions by construction.
## ---------------------------------------------------------------------------
##
## ⚠ A SELF-TEST THAT ONLY ASSERTS THE CHECK FIRES PROVES NOTHING ABOUT WHETHER
## IT OVER-FIRES, and on a 1047-file corpus an over-firing checker is worse than
## none: it gets disabled, and a disabled checker is how the cleanup rots (D9).
## The sibling tool measured this the same day -- closescan.py self-tested one
## true positive, and 4 of the 7 issues it reported as closed-but-marked-open
## were false: two of them literally read "FILED, **not** closed: issue NNNN",
## with the negation sitting inside the regex's own 40-character gap.  Acting on
## that table would have marked two genuinely open defects closed, one carrying
## a live user ruling.  These rows exist to redden if anyone ever "improves" this
## checker by inferring from prose what the grammar requires to be declared.

check "N1 prose that claims to close another issue is NOT treated as closure" \
    [lassign [mkcorpus proseclose [list 9999-x.md "# 9999 - x

**STAMP:** `v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=1`

This closes issue 0650 and fixes issue 0947 at the same time, and it is
FILED, not closed: issue 0516.  All three of those sentences are prose."] ""] id bf ;
     llength [with_corpus $id $bf {istamp::gate}]] \
    0

check "N2 a fenced block with no attributes is an ordinary code sample, not a quote to verify" \
    [lassign [mkcorpus plainfence [list 9999-x.md "# 9999 - x

**STAMP:** `v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=0`

```c
int this_function_has_never_existed(void) { return 0; }
```"] ""] id bf ;
     llength [with_corpus $id $bf {istamp::gate}]] \
    0

## 0216 is fixed for the Location bar and wviewer::restore and NOT for the ASE
## re-run path; 0650's general channel landed at 5dd68128 while its titular
## session-window sink did not.  A binary schema closes both wrongly, and
## closing a live defect is the STALE-OPEN direction -- the dangerous one.
check "N3 scope= expresses a defect closed on one route and live on another (0216, 0650)" \
    [list [dict get [istamp::parse_stamp \
             "**STAMP:** `v1 claim=partial tree=$REV stamped=2026-09-17 fix=taken open=1 scope=ase-rerun-path`"] ok] \
          [dict get [istamp::parse_stamp \
             "**STAMP:** `v1 claim=partial tree=$REV stamped=2026-09-17 fix=taken open=1 scope=has spaces`"] ok]] \
    {1 0}

## ---------------------------------------------------------------------------
## D9 -- the constraint the whole design was built around
## ---------------------------------------------------------------------------
##
## T1's baseline is ZERO counted failures and CLAUDE.md is emphatic that a
## standing red is a defect, not furniture.  A checker that failed 1047 files on
## the day it landed would either redden T1 permanently or, far likelier, be
## quietly disabled -- and a disabled checker is exactly how the cleanup rots.

check "D9 the gate is GREEN on the real corpus as it stands today" \
    [llength [istamp::gate]] \
    0

check "D9b the self-test is a precondition of any verdict, not a separate command" \
    [llength [istamp::selftest]] \
    0

## Sweep this run's fixture corpora.  A leak here would land in
## tests/headless/.scratch/, which is gitignored, but the pile is the subject of
## issue 0148 and there is no reason to add to it.
catch {file delete -force [file join [file dirname [file normalize [info script]]] .scratch]}

if {$fail == 0} {
    puts "RESULT: ALL PASS ($npass checks)"
    puts "OVERALL: ok"
    exit 0
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
    puts "OVERALL: notok"
    exit 1
}
