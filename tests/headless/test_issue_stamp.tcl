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

## ---------------------------------------------------------------------------
## Scratch discipline: THIS RUN'S DIRECTORIES, AND NOTHING ELSE
## ---------------------------------------------------------------------------
##
## ⚠ THIS FILE USED TO END WITH A SINGLE UNQUALIFIED DELETE:
##
##     file delete -force <tests/headless>/.scratch
##
## -- the WHOLE shared scratch tree, not this run's own directories.  Creation
## was pid-qualified and correct all along (`istamp_[pid]_<tag>` below, and
## `drv_[pid]` in row S20); only the sweep was qualified by POSITION -- the
## directory it happened to sit in -- instead of by IDENTITY, the directories
## this process actually made.  That is `W12b`, *position is not identity*: the
## defect class the harness-concurrency batch existed to fix, reproduced inside
## the file this batch built to enforce its own convention.
##
## ⚠ IT IS NOT THEORETICAL AND IT REDDENED THE GATE.  `.scratch` is the shared
## namespace `tests/headless/scratch.tcl` hands directories out of --
## `test_scratch <tag>` returns `.scratch/_<tag>_<pid>` -- and 192 files under
## tests/ source that library (187 `test_*.tcl` suites plus 5 helpers), measured
## by an anchored `^\s*source .*scratch\.tcl` rather than by a bare substring:
## 194 files merely CONTAIN the string, this one included, and counting those
## would be the `pgrep -af` self-match again.  Measured 2026-09-17: run by hand while T1 was
## live, this line removed `_simcaps0948_<pid>` and `_conc1476_<pid>` mid-run,
## and T1 returned `counted_failures=55` with 42 of them from
## `test_ase_simcaps_0948` alone.  The suite reported `RESULT: ALL PASS` and
## exited 0 while doing it, which is exactly why nothing caught it for a day.
##
## The replacement is scratch.tcl's own division of labour, COPIED rather than
## invented, because a correct implementation already exists in this tree:
##
##   * directories this process creates are REGISTERED at creation and deleted
##     from that record -- identity, never a pattern (scratch.tcl's
##     `__scratch_dirs` / `__scratch_cleanup_all`);
##   * corpses left behind by runs that were killed are swept only on EVIDENCE
##     that their owner is gone, behind the same guards as scratch.tcl's
##     `__scratch_sweep` and `run_regression.tcl`'s `t1_sweep_verdicts`.
##
## ⚠ `.scratch` ITSELF IS NEVER DELETED, and the failure direction is always
## "a leftover survives", never "a live run's state is deleted".

## Resolve the scratch root ONCE, at the top level, while [info script] still
## names this file -- the discipline scratch.tcl states for `__scratch_home`.
## The creators and the sweep must agree on the root, or the sweep looks in the
## wrong place and silently does nothing.
set ::ISTAMP_SCRATCH_ROOT \
    [file join [file dirname [file normalize [info script]]] .scratch]

## The record of what this process made.
if {![info exists ::ISTAMP_OWN_DIRS]} { set ::ISTAMP_OWN_DIRS {} }

proc istamp_own {d} {
    if {[lsearch -exact $::ISTAMP_OWN_DIRS $d] < 0} {
        lappend ::ISTAMP_OWN_DIRS $d
    }
    return $d
}

## Delete exactly the directories handed over.  No glob and no pattern: the
## caller supplies the record of what it created, which is the whole point.
proc istamp_delete_own {dirs} {
    set gone {}
    foreach d $dirs {
        if {![file exists $d]} { continue }
        if {![catch {file delete -force $d}]} { lappend gone [file tail $d] }
    }
    return $gone
}

## Is $p a live process?  Conservative, exactly as scratch.tcl's
## `__scratch_pid_alive`: when we cannot tell, answer "alive", so a sweep never
## removes a directory another running test still owns.
proc istamp_pid_alive {p} {
    if {![string is integer -strict $p]} { return 1 }
    if {[file isdirectory /proc]} { return [file exists /proc/$p] }
    return 1
}

## Sweep same-shaped corpses of runs that never reached their own cleanup.
## FOUR guards before any delete, every one of them load-bearing:
##   1. the name must be THIS SUITE's shape -- `istamp_<pid>_<tag>` or
##      `drv_<pid>` -- so `_simcaps0948_<pid>`, and every other suite's
##      directory, is invisible to this loop;
##   2. the pid must not be mine (my own go through the record above);
##   3. the pid must be DEAD on evidence: /proc absent, never a bare `kill -0`,
##      which answers yes for a RECYCLED pid;
##   4. the directory must be older than $min_age -- belt and braces against
##      pid reuse on a box that just wrapped its pid space (pid_max here is
##      4194304), the same floor `__scratch_sweep` carries.
## `$root` itself is never touched.
proc istamp_sweep_corpses {root {min_age 300}} {
    set gone {}
    if {![file isdirectory $root]} { return $gone }
    set now [clock seconds]
    foreach d [concat \
            [glob -nocomplain -directory $root -type d {istamp_[0-9]*_*}] \
            [glob -nocomplain -directory $root -type d {drv_[0-9]*}]] {
        set base [file tail $d]
        if {![regexp {^istamp_([0-9]+)_.+$|^drv_([0-9]+)$} $base -> p1 p2]} { continue }
        set p [expr {$p1 ne {} ? $p1 : $p2}]
        if {$p eq [pid]} { continue }
        if {[istamp_pid_alive $p]} { continue }
        if {[catch {file mtime $d} mt]} { continue }
        if {$now - $mt < $min_age} { continue }
        if {![catch {file delete -force $d}]} { lappend gone $base }
    }
    return $gone
}

proc mkcorpus {tag files {baseline ""}} {
    set d [istamp_own [file join $::ISTAMP_SCRATCH_ROOT istamp_[pid]_$tag]]
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

## ⚠ HEAD'S ABBREVIATION IS NOT GUARANTEED TO BE A LEGAL `tree=` TOKEN, AND ON
## 2026-09-17 IT WAS NOT.  The grammar requires 7-40 hex with AT LEAST ONE a-f
## (issue_stamp.tcl's `tree=... is not a revision (7-40 hex, at least one a-f)`
## arm) -- a rule stolen from tools/stampscan.py because a bare [0-9a-f]{8,40}
## matched `16091816`, the box's MemTotal in kB, and led a whole census astray.
## THAT RULE IS RIGHT AND MUST NOT BE LOOSENED TO MAKE THIS SUITE PASS.
##
## But an 8-char abbreviation is all decimal digits with probability
## (10/16)^8 = 2.3%, and measured over this branch's last 300 commits it is
## 6 of 300 -- 2%.  At HEAD `83656487` the fixtures built from $REV stopped
## parsing and TWELVE rows went red at once -- S15, S15c, B3, G2, Q1, Q2, A2,
## A3, A4, N1, N2, N3 -- with nothing about the tree changed and nothing wrong
## with the checker.  Only the SPELLING OF HEAD had changed.  An earlier run of
## this same suite cost an evening of hypotheses about concurrency, corpora and
## shared scratch before anyone suspected the revision itself.
##
## So: lengthen the abbreviation until it carries a hex letter.  Every form
## names the SAME commit, `git show` and `cat-file` accept all of them, and the
## full 40-char object name is the backstop.
proc istamp_test_rev {} {
    foreach n {8 9 10 12 40} {
        if {[catch {exec timeout 30 git -C $istamp::repo rev-parse --short=$n HEAD} r]} {
            continue
        }
        set r [string trim $r]
        if {[regexp {^[0-9a-f]{7,40}$} $r] && [regexp {[a-f]} $r]} { return $r }
    }
    return {}
}
set REV [istamp_test_rev]

puts "## issue-stamp checker, corpus [file tail $istamp::issues_dir], tree $REV"

## ⚠ ONE NAMED ROW INSTEAD OF TWELVE MYSTERIOUS ONES.  If the revision this
## suite builds its fixtures from is ever not a legal tree= token again, THIS
## row says so by name -- instead of twelve unrelated-looking rows failing at
## once and a reader spending an evening refuting hypotheses about concurrency,
## which is precisely what happened on 2026-09-17.  A stall must be a named
## outcome; so must this.
check "S0 the revision the fixtures are built from is itself a legal tree= token" \
    [list [expr {$REV ne {}}] \
          [dict get [istamp::parse_stamp \
              "**STAMP:** `v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=0`"] ok] \
          [istamp::rev_exists $REV]] \
    {1 1 1}

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

## ⚠ RED WHEN WRITTEN, AND S15 ABOVE IS THE REASON IT COULD HIDE.
## `format_stamp` iterated {claim tree stamped fix open super by}.  `scope` was
## not in that list, though `parse_stamp` accepts it and `ok_key` contains it --
## so ANY round-trip through the formatter silently deleted the one field that
## records a defect closed on one route and live on another.  0216 is fixed for
## the Location bar and `wviewer::restore` and NOT for the ASE re-run path;
## 0650's general channel landed while its titular session-window sink did not.
## Both are stamped with a scope in this tree today.  Dropping it closes a live
## defect, which is the STALE-OPEN direction -- the one the spec calls dangerous.
##
## S15 could not see it, and the reason generalises: ITS FIXTURE CARRIES NO
## SCOPE, and a round-trip whose input lacks a field cannot detect a formatter
## that drops it.  Vacuous green, for the third time in this batch (BC1's
## rev_exists, BC1's row B1, and this), twice inside the machinery built to
## treat it.  Found by D1 (receipt F2) by reading, not by any row going red.
check "S15b the formatter EMITS scope= -- it used to drop the field silently" \
    [string match "*scope=ase-rerun-path*" [istamp::format_stamp \
        [dict create claim partial tree $REV stamped 2026-09-17 fix taken open 1 \
                     scope ase-rerun-path by D1]]] \
    1

## The other direction, and the one that generalises past `scope`: asserted as a
## whole dict rather than as `ok`, so a key added to the grammar and forgotten in
## the formatter reddens here instead of evaporating on the next rewrite.
## Canonicalised, so this asks "did a field go missing?" and not "did anyone
## reorder the key list?".
check "S15c a round-trip carrying EVERY optional field loses nothing" \
    [set full [dict create claim partial tree $REV stamped 2026-09-17 fix taken \
                           open 1 super 0655 scope ase-rerun-path by D1] ;
     set got [istamp::parse_stamp [istamp::format_stamp $full]] ;
     list [dict get $got ok] \
          [expr {[istamp::dict_canon [dict get $got f]] eq [istamp::dict_canon $full]}]] \
    {1 1}

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
    [set d [istamp_own [file join $::ISTAMP_SCRATCH_ROOT drv_[pid]]] ;
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

## ⚠ RED WHEN WRITTEN, ON REAL DATA RATHER THAN ON A FIXTURE, AND IT NAMED THE
## FILE.  `format_stamp` is the WRITER; if it cannot reproduce what is already on
## disk, then any `restamp` helper, any tidy-up pass, any future tool that reads a
## stamp and writes it back CORRUPTS the corpus silently.  Measured by the driver
## at d09ebece: `scope=` occurs exactly ONCE in all 1047 files -- on 0216 -- so
## the blast radius was one file, and one file is enough, because that one file is
## the case the field was invented for.  Against the broken formatter this row
## answered `0216:scope`.
##
## Field-wise and canonicalised, NOT byte-identical: this must ask "did a field go
## missing?", never "did anyone reorder the key list?".  An over-firing row on a
## 1047-file corpus is worse than no row, because it gets the checker disabled --
## which is D9, and how a cleanup rots.
check "B4 every stamp in the real corpus round-trips through the formatter with no field lost" \
    [set lost {} ;
     foreach {num fname} [istamp::issue_files] {
        set fs [istamp::find_stamp [istamp::read_file \
                    [file join $istamp::issues_dir $fname]]] ;
        if {[dict get $fs n] != 1} { continue } ;
        set p [istamp::parse_stamp [dict get $fs line]] ;
        if {![dict get $p ok]} { continue } ;
        set f [dict get $p f] ;
        set back [istamp::parse_stamp [istamp::format_stamp $f]] ;
        if {![dict get $back ok]} { lappend lost $num:unparseable ; continue } ;
        if {[istamp::dict_canon [dict get $back f]] ne [istamp::dict_canon $f]} {
            set miss {} ;
            foreach k [dict keys $f] {
                if {![dict exists [dict get $back f] $k]} { lappend miss $k }
            } ;
            lappend lost $num:[expr {[llength $miss] ? [join $miss ,] : {value-changed}}]
        }
     } ;
     set lost] \
    {}

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

## ---------------------------------------------------------------------------
## W -- THE SWEEP.  This section locks a defect that was LIVE IN THIS FILE.
## ---------------------------------------------------------------------------
##
## ⚠ RED WHEN WRITTEN, ON THE REAL TREE, AND IT COST A T1 RUN.  The mechanism is
## in the block above `mkcorpus`; this is what was observed at bb3eeb81.  Three
## sentinel directories were placed in `.scratch` -- `_bc3_sentinel_<pid>` plus
## replicas of the two real victims, `_simcaps0948_*` and `_conc1476_2642112` --
## and ALL THREE, together with `.scratch` itself, were destroyed by a run of
## this suite that reported `RESULT: ALL PASS (43 checks)` / `OVERALL: ok` /
## rc 0, identically on the tclsh arm and the xschem arm.  A green suite
## deleting three other suites' live state is the shape nothing in this project
## catches, and it is the reason these rows exist.
##
## ⚠ THESE ROWS RUN AGAINST A FIXTURE ROOT, NEVER THE REAL ONE, so the suite
## cannot damage a concurrent run even while proving that it does not.

## A throw-away scratch root with $entries as its children.  Registered, so the
## real cleanup below removes it however this suite ends.
proc mksweepfix {tag entries} {
    set root [istamp_own [file join $::ISTAMP_SCRATCH_ROOT istamp_[pid]_$tag]]
    file delete -force $root
    file mkdir $root
    foreach e $entries { file mkdir [file join $root $e] }
    return $root
}

proc sweepfix_left {root} {
    set out {}
    foreach d [glob -nocomplain -directory $root -type d *] {
        lappend out [file tail $d]
    }
    return [lsort $out]
}

## A pid that owns nothing: below pid_max, so it is a well-formed pid, and with
## no /proc entry, so it is dead ON EVIDENCE rather than by assumption.
set W_DEAD 0
for {set n 4000000} {$n < 4000200} {incr n} {
    if {![file exists /proc/$n]} { set W_DEAD $n ; break }
}

check "W1 cleanup deletes the directories this run RECORDED -- and only those" \
    [set r [istamp_own [file join $::ISTAMP_SCRATCH_ROOT istamp_[pid]_ownfix]] ;
     file delete -force $r ; file mkdir $r ;
     foreach e {recorded_a recorded_b never_recorded} { file mkdir [file join $r $e] } ;
     set gone [lsort [istamp_delete_own \
         [list [file join $r recorded_a] [file join $r recorded_b]]]] ;
     list $gone [sweepfix_left $r]] \
    {{recorded_a recorded_b} never_recorded}

## One fixture, one sweep, and the rows below read different guards off it.
set W_FIX [mksweepfix sweepfix [list \
    istamp_[pid]_mine  drv_1  istamp_1_live \
    istamp_${W_DEAD}_corpse  drv_${W_DEAD} \
    _simcaps0948_${W_DEAD}  _conc1476_2642112]]
set W_SWEPT [lsort [istamp_sweep_corpses $W_FIX 0]]
set W_LEFT  [sweepfix_left $W_FIX]

check "W2 the sweep removes exactly the DEAD pids' own-namespace dirs, nothing else" \
    [list $W_SWEPT $W_LEFT] \
    [list [lsort [list drv_${W_DEAD} istamp_${W_DEAD}_corpse]] \
          [lsort [list _conc1476_2642112 _simcaps0948_${W_DEAD} \
                       drv_1 istamp_1_live istamp_[pid]_mine]]]

## ⚠ THE SENTINEL, MECHANISED.  pid 1 is alive on every Linux box there is, so a
## sweep that removed `istamp_1_live` would be deleting a LIVE run's state --
## which is what the old line did to every suite at once.
check "W3 a LIVE pid's directory is never swept, even in this suite's own namespace" \
    [list [expr {[lsearch -exact $W_LEFT istamp_1_live] >= 0}] \
          [expr {[lsearch -exact $W_LEFT drv_1] >= 0}] \
          [istamp_pid_alive 1]] \
    {1 1 1}

## ⚠ THE MEASURED VICTIM.  `_simcaps0948_<pid>` is the literal directory
## test_ase_simcaps_0948 asks `test_scratch` for, and `_conc1476_2642112` is what
## `.scratch` actually held -- test_regression_concurrency_1476 running INSIDE a
## live T1 -- at the moment the old line fired.  Neither is in this suite's
## namespace, so neither may EVER be reachable from here, dead pid or not.
check "W4 a directory outside this suite's namespace is invisible to the sweep" \
    [list [expr {[lsearch -exact $W_LEFT _simcaps0948_${W_DEAD}] >= 0}] \
          [expr {[lsearch -exact $W_LEFT _conc1476_2642112] >= 0}]] \
    {1 1}

## ⚠ NON-VACUITY.  W3 and W4 are "it survived" rows, and a sweep that did
## nothing whatsoever would pass both.  This is the row that says it works.
check "W5 a dead pid's corpse IS swept, so W3 and W4 are not passing on a no-op" \
    [list [expr {[lsearch -exact $W_SWEPT istamp_${W_DEAD}_corpse] >= 0}] \
          [expr {$W_DEAD > 0}] [istamp_pid_alive $W_DEAD]] \
    {1 1 0}

## The age floor -- scratch.tcl's "belt-and-braces against pid reuse on a box
## that just wrapped its pid space".  A FRESH directory owned by a dead pid is
## the shape a recycled pid produces, so it must survive the default budget.
check "W6 the age floor spares a dead pid's FRESH directory (pid reuse)" \
    [set f [mksweepfix agefix [list istamp_${W_DEAD}_fresh]] ;
     list [istamp_sweep_corpses $f] [sweepfix_left $f] [file isdirectory $f]] \
    [list {} [list istamp_${W_DEAD}_fresh] 1]

## ⚠ THE HEADLINE.  The root is 192 files' shared namespace and is NOT this
## suite's to delete.  Deleting it was the old line's entire content.
check "W7 the scratch ROOT itself survives a sweep -- it is 192 files' namespace" \
    [list [file isdirectory $W_FIX] [file isdirectory $::ISTAMP_SCRATCH_ROOT]] \
    {1 1}

## Sweep: this run's own directories, from the record of what it made, and then
## -- only on evidence the owner is gone -- same-shaped corpses of runs that
## were killed before they got here.  `.scratch` ITSELF IS NOT DELETED.
catch {istamp_delete_own $::ISTAMP_OWN_DIRS}
set ::ISTAMP_OWN_DIRS {}
catch {istamp_sweep_corpses $::ISTAMP_SCRATCH_ROOT}

if {$fail == 0} {
    puts "RESULT: ALL PASS ($npass checks)"
    puts "OVERALL: ok"
    exit 0
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
    puts "OVERALL: notok"
    exit 1
}
