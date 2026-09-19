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
## It needs git HISTORY only for the rows that ask about revisions, and it no
## longer needs the checkout to be called anything in particular, or to be
## writable.  In a shallow clone whose HEAD history is cut short, a no-.git
## export (a Download ZIP, a git archive) or a `git init` with nothing
## committed, those rows SKIP BY NAME and everything else still runs -- see the
## HISTORY section below.  A repository git merely CALLS shallow, because a
## boundary sits on some other branch, is not one of those: HEAD's history is
## whole there, and it is checked as a full clone (D15).  Nor is a download put
## under git AND COMMITTED: it is a history that does not hold this project's
## revisions, and the suite is RED there, saying why and what cures it (a real
## clone).
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

## ---------------------------------------------------------------------------
## HISTORY -- what this tree can and cannot be asked
## ---------------------------------------------------------------------------
##
## ⚠ THIS SUITE WAS REGISTERED IN T1 AND TURNED IT RED FOR MOST STRANGERS.
## Measured 2026-09-18 by the outsider-fixes batch (audit F21/F23/F24), at
## 4b9565ad, in three ordinary ways of getting this tree:
##   * a full clone into a folder called `xschem`: RESULT: 1 FAILED -- row S20,
##     which compared the folder's NAME with the literal `xschem-claude`;
##   * a `--depth 1` clone: S20, plus D9 `got: 10` -- every stamp names
##     61af3692, an ancestor of HEAD a shallow clone does not fetch;
##   * a `git archive` export with no .git: S0, S15 and S15c red on an EMPTY
##     revision, then S20's driver died on `istamp::rev_exists ` with no
##     argument, killing the suite mid-file and leaving `.scratch/drv_<pid>`.
## None of those is a defect in the corpus.  All of them are the checker
## reporting that history it was never given is missing.
##
## So the checker classifies the tree once (istamp::history_probe), on positive
## evidence only, and every row DECLARES what it needs.  A row whose need is
## absent prints a `skip:` line naming itself and the reason, is counted in the
## banner, and verified nothing.  It is never a pass and never a FAIL.
##
## ⚠ A HISTORY WITH COMMITS SKIPS NOTHING (outsider-fixes DECISIONS D14).  S1's
## refuters measured a download put back under git by hand (`git init && git
## add -A && git commit`) going red, and two rounds tried to keep it green.
## S1-fix's `foreign` state ("the project's first commit is not here, skip it
## all") failed open: a history rewritten from its root went GREEN verifying
## nothing.  S1-fix2's per-stamp date rule ("skip what was stamped before this
## history began") failed open too, on the stamp's OWN date: a typo'd
## `stamped=2016-09-17` turned a bogus tree= GREEN in an ordinary full clone,
## and a graft, an orphan squash and a root-date rewrite did the same.  Each
## round weakened the one state that must be strict, so now there is no such
## exemption: that download is RED, by design, and its red says why.  These
## rows keep it honest:
##   H6  this tree's verdict agrees with the evidence ON DISK (.git, git's own
##       `shallow` file, an unborn HEAD), read without asking git;
##   H9  every stamped revision in the real corpus resolves, asked of git
##       directly rather than through the gate;
##   D9h the gate verified every one of them and skipped NOTHING;
##   H11/H13  a planted bogus stamp is RED in every full-history shape --
##       backdated, dated `0000-00-00`, grafted, orphan-squashed, re-dated;
##   H7  the set of rows that skipped is EXACTLY the declared set for this
##       state -- in a full clone, EMPTY.  A row that starts skipping without
##       being declared, or a full clone that skips anything, is red.
## And, from D15 (S1-fix3's refuter found each one failing open):
##   H16 a shallow boundary OFF HEAD's path -- `fetch --depth 1` of another
##       branch, an empty `shallow` file, a depth reaching the root -- is a
##       FULL history, and a planted bogus stamp in it is RED;
##   H1  a .git that is a dangling link, or a gitfile naming nothing, is
##       `unreadable`, never `none`;
##   H17 no text from an issue file reaches git as an option: `quote=--output=
##       <file>` is a named problem and writes nothing;
##   H18 a revision that resolves but is not in HEAD's history -- amended away
##       -- is RED (and NOT VERIFIED, by name, above a shallow boundary);
##   Q3/Q4  a quote= or **STAMP:** the parser does not read is a named problem.
## And from D16 (S1-fix4's refuter, again one step past the last fix):
##   Q5  no exec carries text from an issue file: assert= patterns that Tcl's
##       exec read as redirections and pipes -- `>`, `2>`, `|`, `2>/dev/null`,
##       `2>&1` -- are counted as literal text, and nothing is written or run;
##   Q6  an assert= path= cannot leave the checkout (absolute, `..`, a symbolic
##       link out), and nothing outside it is read;
##   H19 a no-op `fetch --depth 1` of HEAD or of an ancestor is not shallow: the
##       store holds everything, and a bogus stamp is RED;
##   H20 in a shallow clone a tree= naming a blob or a tree is RED;
##   H21 the caller's GIT_SHALLOW_FILE cannot steer the probe;
##   Q7/Q8  fences close the CommonMark way, and a stamp is recognised in any
##       spelling of bold.
## And from D19 (S1-fix6's refuter, inside D18's threat model):
##   Q13 report, and this suite's own corpus reads (B1, B4, the D9 census), read
##       nothing outside the checkout, and report runs no program;
##   Q14 a gate run's assert= scans share ONE budget, and a block reached after
##       it is spent is a named problem;
##   Q15 a marked fence's info string is read in full: a multi-word pat= is a
##       named problem, never a weaker claim evaluated in silence;
##   Q16 a line carrying a stamp's body that the parser does not read -- a stamp
##       that lost its colon -- is a named problem;
##   Q17 grandfathering is by EXACT FILE NAME, so a new file under a colliding
##       number is RED, and a name that misses NNNN-<slug>.md is named;
##   H22 no git call fetches: in a partial clone a quote of content that is not
##       in the checkout is NOT VERIFIED by name, and nothing is fetched.
##
## ⚠ AND IN THE ONE STATE THAT IS MEANT TO BE RED -- `unreadable`: a .git that
## git cannot read, e.g. git's dubious-ownership refusal in a container whose
## checkout another uid owns, or git missing from PATH -- THE SUITE STILL REACHES
## ITS RESULT LINE.  S1's refuters measured it dying at Q1 instead, on an
## uncaught `git show`, with every row after it unrun and seven scratch
## directories left behind.  check_needs now catches a row that dies and scores
## it a named FAIL, and Q1 catches its own exec.
set HSTATE [istamp::history_state]
set HWHY   [istamp::history_why]

## The repository root, derived from THIS SUITE's own location -- independently
## of the checker, which derives its own from ITS location.  S20 compares the two.
set ROOT [file dirname [file dirname [file dirname [file normalize [info script]]]]]

## Judged by EXIT CODE, stderr discarded -- as every git call in the checker
## is (istamp::git_run).  A tester's GIT_TRACE, or a git that warns about their
## config, writes to stderr on every command, and Tcl's exec takes ANY stderr
## as failure: this row would then call git "not installed" while the probe
## had just used it.
set HAVE_GIT [expr {![catch {exec timeout 30 git --version 2>/dev/null}]}]

## What each row needs beyond the checker itself.  Declared once, here, so that
## H7 can hold the skipped set to it.
##   NEEDS_REPO     a git repository of this tree's own, with a HEAD that names
##                  a commit -- present in a shallow clone and any full history,
##                  absent from an export and from a `git init` with nothing
##                  committed (`unborn`).  S20c is the HEAD half of S20b
##   NEEDS_DEPTH    a history that is not cut short -- present in `full` (and
##                  asked, and red, in `unreadable`), absent from a shallow
##                  clone, an export and an unborn repo.  G4 is here because in
##                  a shallow clone "deadbee does not resolve" cannot be told
##                  apart from "deadbee is beyond the depth" (H2 proves G4's
##                  refusal on a fixture repository in every shape instead); H9
##                  and D9h ask the real corpus's revisions.  ⚠ There used to be
##                  a NEEDS_HISTORY, skipped also in a full history that "began
##                  after every stamp"; D14 removed that exemption, and with it
##                  the only thing that told the two lists apart
##   NEEDS_GITBIN   only the git program: the H rows build their own repositories
set NEEDS_REPO    {S0 S20c Q1 Q2}
set NEEDS_DEPTH   {G4 H9 D9h}
set NEEDS_GITBIN  {H0 H1 H2 H3 H4 H5 H8 H10 H11 H12 H13 H14 H15 H16 H17 H18 H19 H20 H21 H22 Q7}

set ::SKIPPED {}

proc row_id {name} { return [lindex [split $name] 0] }

## Why row $id cannot run in this tree, or "" if it can.  Decided by the state
## alone: nothing about a full history can block a row.
proc row_blocked {id} {
    global HSTATE HWHY HAVE_GIT
    global NEEDS_REPO NEEDS_DEPTH NEEDS_GITBIN
    if {$id in $NEEDS_DEPTH   && $HSTATE in {shallow none unborn}} { return $HWHY }
    if {$id in $NEEDS_REPO    && $HSTATE in {none unborn}}         { return $HWHY }
    if {$id in $NEEDS_GITBIN  && !$HAVE_GIT}                       { return "git is not installed" }
    return ""
}

## A NAMED skip.  Never at column 0 as `SKIP:` or `RESULT: SKIP` -- those are
## the whole-suite self-skip banners full_audit.sh and run_suites.sh read -- and
## never ending in the word T1 counts.  Recorded, so the banner and H7 see it.
proc skip {name why} {
    lappend ::SKIPPED [row_id $name]
    puts "skip: $name -- NOT VERIFIED: $why"
}

## `check`, for a row with a declared need: the got-script is evaluated ONLY if
## the need is met, so a row that cannot run never half-runs.
##
## ⚠ AND A ROW THAT DIES IS A NAMED FAIL, NEVER A DEAD SUITE.  This comment used
## to promise "never dies" while the script ran uncaught -- and in the
## `unreadable` state Q1's `git show` threw straight through it, killing the
## suite with every row after Q1 unrun, no RESULT line, and seven
## istamp_<pid>_* directories left behind (MEASURED by S1's refuters, and again
## by S1-fix).  An error from the script is now the row's `got`, first line
## only, so the reader sees WHICH row and WHY, and every row after it still runs.
proc check_needs {name script want} {
    set why [row_blocked [row_id $name]]
    if {$why ne ""} { skip $name $why ; return }
    if {[catch {uplevel 1 $script} got]} {
        set got "ROW DIED: [lindex [split $got \n] 0]"
    }
    check $name $got $want
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
##
## ⚠ A READ-ONLY CHECKOUT IS A SHAPE, NOT A DEFECT IN THE CORPUS -- a checkout on
## a read-only mount, a package build, a CI cache.  S1-fix's refuter MEASURED
## this suite dying there at its first write (S20's `file mkdir`), with every row
## after it unrun and no RESULT line.  So when `.scratch` cannot be written this
## run's directories go OUTSIDE the checkout, in one directory of its own under
## the temp root, and the header says so; the shared `.scratch` is still the one
## the corpse sweep reads.  If neither can be written the suite does not limp on
## into a death at some later row: it reports that, by name, and ends.
set ::ISTAMP_SHARED_SCRATCH \
    [file join [file dirname [file normalize [info script]]] .scratch]
set ::ISTAMP_SCRATCH_ROOT $::ISTAMP_SHARED_SCRATCH
set ::ISTAMP_TEMP_ROOT    ""
set ::ISTAMP_SCRATCH_ERR  ""
if {[catch {
        set t [file join $::ISTAMP_SHARED_SCRATCH istamp_[pid]_wprobe]
        file mkdir $t
        close [open [file join $t w] w]
        file delete -force $t
    } e1]} {
    set tmp /tmp
    if {[info exists ::env(TMPDIR)] && [file isdirectory $::env(TMPDIR)]} { set tmp $::env(TMPDIR) }
    ## Named in this suite's own corpse namespace, so a run that dies after
    ## making it leaves a corpse the sweep below knows how to recognise.
    set ::ISTAMP_TEMP_ROOT [file join [file normalize $tmp] istamp_[pid]_tmproot]
    if {[catch {
            file delete -force $::ISTAMP_TEMP_ROOT
            file mkdir $::ISTAMP_TEMP_ROOT
            close [open [file join $::ISTAMP_TEMP_ROOT w] w]
        } e2]} {
        set ::ISTAMP_SCRATCH_ERR "neither [file tail $::ISTAMP_SHARED_SCRATCH] ([lindex [split $e1 \n] 0]) nor $::ISTAMP_TEMP_ROOT ([lindex [split $e2 \n] 0]) can be written"
    } else {
        set ::ISTAMP_SCRATCH_ROOT $::ISTAMP_TEMP_ROOT
        puts "## scratch: $::ISTAMP_SHARED_SCRATCH cannot be written ([lindex [split $e1 \n] 0]) -- a read-only checkout? -- so this run's directories are in $::ISTAMP_TEMP_ROOT"
    }
}

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
## `$patterns` narrows guard 1 further where the root is not this suite's own:
## in the shared temp directory only `istamp_<pid>_tmproot` is ever looked at.
proc istamp_sweep_corpses {root {min_age 300} {patterns {istamp_[0-9]*_* drv_[0-9]*}}} {
    set gone {}
    if {![file isdirectory $root]} { return $gone }
    set now [clock seconds]
    set cands {}
    foreach pat $patterns {
        lappend cands {*}[glob -nocomplain -directory $root -type d $pat]
    }
    foreach d $cands {
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
        if {[catch {istamp::git_in $istamp::repo rev-parse --short=$n HEAD} r]} {
            continue
        }
        set r [string trim $r]
        if {[regexp {^[0-9a-f]{7,40}$} $r] && [regexp {[a-f]} $r]} { return $r }
    }
    return {}
}
## ⚠ WITH NO REPOSITORY OF ITS OWN, THIS TREE NEVER ASKS GIT FOR HEAD.  In an
## export, `git rev-parse` either fails -- and $REV came back EMPTY, which is how
## S0, S15 and S15c went red and S20's driver died -- or, if the export was
## unpacked inside some other repository, SUCCEEDS with that repository's HEAD.
## The parse-level rows need only a LEGAL token, so they get a fixed one and
## still run; the rows that need HEAD itself (NEEDS_REPO) skip by name.  An
## `unborn` repository -- `git init`, nothing committed -- has a .git and no
## HEAD to name, and is treated exactly the same way.
##
## ⚠ THE SAME FIXED TOKEN STANDS IN WHEN THERE IS A .git AND GIT CANNOT READ HEAD
## (`unreadable`).  With $REV empty, rows that only PARSE -- S15, S15c and B3,
## MEASURED by S1's refuters, and N3 had the suite lived to reach it -- went red
## on "tree= is not a revision": a red that names the wrong cause.  The
## real cause is reported ONCE, by name, by S0 (which reads $REV_HEAD, what git
## actually answered), and the gate rows then go red for the reason the design
## gives: in `unreadable` every revision question is refused.
set REV_HEAD {}
if {$HSTATE in {none unborn}} {
    set REV d64686a1
    set REV_FROM "a fixed token -- no commit here (`$HSTATE`), so git is not asked for HEAD"
} else {
    set REV_HEAD [istamp_test_rev]
    if {$REV_HEAD ne ""} {
        set REV $REV_HEAD
        set REV_FROM HEAD
    } else {
        set REV d64686a1
        set REV_FROM "a fixed token -- git could not read HEAD in this `$HSTATE` tree; row S0 reports it"
    }
}

puts "## issue-stamp checker, corpus [file tail $istamp::issues_dir], tree $REV ($REV_FROM)"
puts "## history: $HSTATE -- $HWHY"

## No scratch directory at all: every row below writes one, so none of them can
## run.  Say so by name and end -- never a death at whichever row writes first.
if {$::ISTAMP_SCRATCH_ERR ne ""} {
    check "X0 this run has a scratch directory -- .scratch, or one outside a read-only checkout" \
        $::ISTAMP_SCRATCH_ERR ""
    puts "RESULT: $fail FAILED ($npass passed -- no scratch directory, so no other row could run)"
    puts "OVERALL: notok"
    exit 1
}

## ⚠ ONE NAMED ROW INSTEAD OF TWELVE MYSTERIOUS ONES.  If the revision this
## suite builds its fixtures from is ever not a legal tree= token again, THIS
## row says so by name -- instead of twelve unrelated-looking rows failing at
## once and a reader spending an evening refuting hypotheses about concurrency,
## which is precisely what happened on 2026-09-17.  A stall must be a named
## outcome; so must this.
check_needs "S0 git reads HEAD here, and the revision the fixtures are built from is a legal tree= token" {
    list [expr {$REV_HEAD ne {}}] \
         [dict get [istamp::parse_stamp \
             "**STAMP:** `v1 claim=open tree=$REV_HEAD stamped=2026-09-17 fix=none open=0`"] ok] \
         [expr {$REV_HEAD ne {} && [istamp::rev_exists $REV_HEAD]}]
} {1 1 1}

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

## ⚠ THE RIGHT SHAPE IS NOT A DATE.  `stamped=0000-00-00` passed the old
## YYYY-MM-DD shape check, and while a per-stamp date rule trusted this field it
## EXEMPTED a bogus tree= in a full clone (MEASURED by S1-fix2's refuter).  The
## rule is gone (D14); a field that states a day must still name one.  The last
## two are the known POSITIVES -- a leap day, and the convention's first day --
## so this row cannot pass by rejecting everything.
check "S9b a date that is not on the calendar is rejected (0000-00-00, Feb 30, month 13, a non-leap Feb 29); real days are not" \
    [set out {} ; foreach d {0000-00-00 2026-02-30 2026-13-01 2025-02-29 2024-02-29 2026-09-17} {
        lappend out [dict get [istamp::parse_stamp \
            "**STAMP:** `v1 claim=open tree=d64686a1 stamped=$d fix=none open=0`"] ok]
     } ; set out] \
    {0 0 0 0 1 1}

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
##
## ⚠ AND IT USED TO ASSERT THE FOLDER'S NAME, WHICH IS NOT THE PROPERTY.  It
## compared `file tail $istamp::repo` with the literal `xschem-claude`, so it went
## red for `git clone <url> xschem`, a second checkout, a worktree, a CI
## workspace and an unpacked ZIP (`xschem-claude-fluid-editing`) -- MEASURED,
## `got: 1 xschem / want: 1 xschem-claude`, with rev_exists = 1, i.e. with the
## checker having found exactly the right repository.  A false red, in T1,
## against a ZERO baseline.  The property is "the checker's repo IS this tree's
## root", so it compares the whole path with $ROOT, which the suite derives from
## its OWN location.  Under BC1's bug the driver's checker lands on
## tests/headless -- two levels above the driver in .scratch -- and this row is
## red whatever the checkout is called.
##
## ⚠ THE DRIVER IS WRITTEN WITH [list], NEVER BY INTERPOLATION, AND ITS EXEC IS
## CAUGHT.  With $REV empty it used to write `puts [istamp::rev_exists ]` --
## a syntax error in the driver that escaped as an uncaught error here and
## KILLED THE SUITE on row S20, leaving every row after it unrun and the driver
## directory behind.  A driver that dies is now a named FAIL of S20/S20b.
## So is one that cannot be WRITTEN: in a read-only checkout the `file mkdir`
## below was the suite's death (MEASURED by S1-fix's refuter); the scratch root
## now falls back outside the checkout, and a write that still fails is S20's
## red, by name, never an uncaught error.
set S20_DRV [istamp_own [file join $::ISTAMP_SCRATCH_ROOT drv_[pid]]]
if {[catch {
        file mkdir $S20_DRV
        set fh [open [file join $S20_DRV drv.tcl] w]
        puts $fh {set ::ISSUE_STAMP_LIB 1}
        puts $fh [list source [file join [file dirname [file normalize [info script]]] issue_stamp.tcl]]
        puts $fh {istamp::init}
        puts $fh [list set rev $REV]
        puts $fh {puts $istamp::repo}
        puts $fh {puts [istamp::history_state]}
        puts $fh {puts [expr {[istamp::history_state] in {none unborn} ? "-" : [istamp::rev_exists $rev]}]}
        close $fh
    } S20_WERR]} {
    set S20_GOT [list "DRIVER NOT WRITTEN: [lindex [split $S20_WERR \n] 0]" {} {}]
} elseif {[catch {exec timeout 60 tclsh [file join $S20_DRV drv.tcl]} S20_RAW]} {
    set S20_GOT [list "DRIVER DIED: [lindex [split $S20_RAW \n] 0]" {} {}]
} else {
    set S20_GOT [split [string trim $S20_RAW] \n]
}
catch {file delete -force $S20_DRV}

check "S20 the repo is derived from the CHECKER's own location, not the caller's script" \
    [lindex $S20_GOT 0] \
    $ROOT

## The driver's checker must also reach THE SAME history verdict as this one.
## In an export both say `none` and neither asks git, which is itself the
## assertion.
check "S20b the driver's checker reaches this tree's history verdict" \
    [lindex $S20_GOT 1] \
    $HSTATE

## ...and, wherever there is a commit for HEAD to name, resolve it through that
## checker.  Its own row, so that where there is none -- an export, an unborn
## repository -- it SKIPS BY NAME instead of passing on a placeholder.
check_needs "S20c the driver's checker resolves this tree's HEAD" {
    lindex $S20_GOT 2
} 1

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
##
## ⚠ AN ISSUE FILE THAT CANNOT BE READ IS THIS ROW'S RED, BY NAME -- NEVER THE
## SUITE'S DEATH.  This read was bare, so one file with no read permission
## (MEASURED by S1-fix's refuter, `chmod 000` on 0056) threw straight out of the
## row and killed the suite with no RESULT line, while the checker's own CLI
## reported the same file cleanly as `0056: unreadable`.  Every read of the real
## corpus in this suite goes through istamp_read_issue, and B1, B4 and the D9
## census each name an unreadable file instead of dying on it.
## ⚠ AND ONE THAT IS NOT A REGULAR FILE IS NEVER OPENED HERE EITHER (D18).  The
## checker names a FIFO or a link in the corpus and does not open it; this
## suite's own census opened every file, so the same FIFO that no longer blocks
## the gate would have blocked B1 instead.
## Asked here with lstat directly, not through the checker's not_regular: this
## is the suite's own evidence, and it must not share the checker's defect.
proc istamp_read_issue {fname} {
    set path [file join $istamp::issues_dir $fname]
    if {[catch {file lstat $path st} e]} { return [list 0 "not opened: [lindex [split $e \n] 0]"] }
    if {$st(type) ne "file"} { return [list 0 "not opened: it is a $st(type), not a regular file"] }
    if {[catch {istamp::read_file $path} t]} {
        return [list 0 [lindex [split $t \n] 0]]
    }
    return [list 1 $t]
}

## ⚠ AND NOTHING IN A CORPUS DIRECTORY THAT LEADS OUT OF THE CHECKOUT IS LISTED
## OR READ HERE EITHER (outsider-fixes DECISIONS D19).  The checker's gate asked
## issues_dir_problem; this suite's own census did not -- it lstat'ed each FILE,
## never the directory -- so with doc/claude/issues committed as a link to a
## copy outside the checkout, B1 printed `got: 1 9997`, a file that exists only
## outside, and read 9998's stamp out there too (MEASURED by S1-fix6's refuter,
## red-first by S1-fix7: `1 {9996 9997}`).  B1, B4 and the D9 census now list
## the corpus ONLY through istamp_corpus_files, which asks the checker's own
## rule first; when it answers, nothing is listed or read and each is red BY
## NAME -- a corpus that cannot be read is not a corpus that passed.  They are
## procs so that row Q13 can point them at a checkout whose corpus directory
## leads out, and hold them to that.
proc istamp_corpus_files {} {
    set dp [istamp::issues_dir_problem]
    if {$dp ne ""} { return [list $dp {}] }
    return [list "" [istamp::issue_files]]
}

## B1's answer: {1 {}} when every file is covered, else what is not.
proc istamp_b1_got {} {
    lassign [istamp_corpus_files] dp files
    if {$dp ne ""} { return [list NOT-READ $dp] }
    lassign [istamp::load_baseline] okb base
    set uncovered {}
    foreach {num fname} $files {
        if {[dict exists $base [istamp::name_key $fname]]} { continue }
        lassign [istamp_read_issue $fname] rok text
        if {!$rok} { lappend uncovered "$num:UNREADABLE" ; continue }
        if {[dict get [istamp::find_stamp $text] n] == 0} { lappend uncovered $fname }
    }
    return [list $okb $uncovered]
}

check_needs "B1 every numbered issue file is covered -- grandfathered in the baseline BY ITS EXACT NAME, or carrying a stamp" {
    istamp_b1_got
} {1 {}}

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
## B4's answer: {} when every stamp round-trips, else what was lost.
proc istamp_b4_got {} {
    set lost {}
    lassign [istamp_corpus_files] dp files
    if {$dp ne ""} { lappend lost NOT-READ $dp }
    foreach {num fname} $files {
        lassign [istamp_read_issue $fname] rok text
        if {!$rok} { lappend lost $num:UNREADABLE ; continue }
        set fs [istamp::find_stamp $text]
        if {[dict get $fs n] != 1} { continue }
        set p [istamp::parse_stamp [dict get $fs line]]
        if {![dict get $p ok]} { continue }
        set f [dict get $p f]
        set back [istamp::parse_stamp [istamp::format_stamp $f]]
        if {![dict get $back ok]} { lappend lost $num:unparseable ; continue }
        if {[istamp::dict_canon [dict get $back f]] ne [istamp::dict_canon $f]} {
            set miss {}
            foreach k [dict keys $f] {
                if {![dict exists [dict get $back f] $k]} { lappend miss $k }
            }
            lappend lost $num:[expr {[llength $miss] ? [join $miss ,] : {value-changed}}]
        }
    }
    return $lost
}

check_needs "B4 every stamp in the real corpus round-trips through the formatter with no field lost" {
    istamp_b4_got
} {}

## The D9 census's reading of the real corpus (used below, in section D9):
## every well-formed stamp as {num tree stamped}.
## Answers {stamps unreadable corpus-problem}.
proc istamp_d9_census {} {
    set stamps {} ; set unreadable {}
    lassign [istamp_corpus_files] dp files
    foreach {num fname} $files {
        lassign [istamp_read_issue $fname] rok text
        if {!$rok} { lappend unreadable $num ; continue }
        set fs [istamp::find_stamp $text]
        if {[dict get $fs n] != 1} { continue }
        set p [istamp::parse_stamp [dict get $fs line]]
        if {[dict get $p ok]} {
            set f [dict get $p f]
            lappend stamps [list $num [dict get $f tree] [dict get $f stamped]]
        }
    }
    return [list $stamps $unreadable $dp]
}

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

**STAMP:** `v1 claim=fixed tree=$REV stamped=2026-09-17 fix=superseded open=0`"] "0001-half-adopted.md"] id bf ;
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

Status: OPEN -- measured 2026-08-22, never stamped.}} "0001-old-file.md"] id bf ;
     llength [with_corpus $id $bf {istamp::gate}]] \
    0

## ⚠ THE FIELD THE WHOLE DESIGN RESTS ON.  Issue 0818 is the one sampled file
## that cited file:line AND named its revision, and `git show fadb226d:` then
## reproduced all four of its dead coordinates EXACTLY -- against 5 of 5 rotted
## for the files that cited bare coordinates.  A tree= that does not resolve
## recovers nothing, so it is the one field worth a hard failure.
##
## ⚠ NEEDS_DEPTH.  In a shallow clone `deadbee` might be a commit beyond the
## depth, and in an export or an unborn repository nothing can be asked at all,
## so here the refusal is unprovable and the row skips by name.  H2 refuses the
## same shape on a fixture repository that DOES carry its whole history, so the
## red is proven in every shape this suite runs in -- only this tree's own copy
## of the row skips.  In EVERY history with commits it is refused, whatever the
## stamp's date: there is no date rule (D14).
check_needs "G4 RED: a tree= that resolves to no commit is refused" {
    lassign [mkcorpus deadrev [list 9999-x.md "# 9999 - x

**STAMP:** `v1 claim=open tree=deadbee stamped=2026-09-17 fix=none open=0`"] ""] id bf
    problems_matching $id $bf "does not resolve"
} 1

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

## ⚠ NEEDS_REPO: both rows read `git show $REV:<path>`.  That exec used to sit
## HERE, at the top level and unguarded, so with no repository it would have
## killed the suite outright -- it was never reached only because S20 died
## first.  It then moved inside Q1, still uncaught, and in the `unreadable`
## state it killed the suite THERE instead.  It is caught now, and a failed
## `git show` is Q1's own named red.
check_needs "Q1 GREEN: a quote that still matches its named revision passes" {
    if {[catch {istamp::git_in $istamp::repo show --end-of-options ${REV}:tests/banner_rule.tcl} q1src]} {
        set q1 "GIT SHOW FAILED: [lindex [split $q1src \n] 0]"
    } else {
        set real_line [lindex [split $q1src \n] 24]
        lassign [mkcorpus quoteok [list 9999-x.md "# 9999 - x

**STAMP:** `v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=0`

```tcl quote=$REV path=tests/banner_rule.tcl
$real_line
```"] ""] id bf
        set q1 [llength [with_corpus $id $bf {istamp::gate}]]
    }
    set q1
} 0

check_needs "Q2 RED: a quote that is no longer in its named revision is refused" {
    lassign [mkcorpus quoterot [list 9999-x.md "# 9999 - x

**STAMP:** `v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=0`

```c quote=$REV path=tests/banner_rule.tcl
Tcl_SetResult(interp, \"xschem set: invalid command.\", TCL_VOLATILE);
```"] ""] id bf
    problems_matching $id $bf "is not in"
} 1

## For each {num needle ...}: how many of the gate's problems for issue $num
## contain $common and, unless it is empty, $needle.  An EMPTY needle counts
## every $common problem for that file -- that is how a known-negative file is
## asked "none at all?" (`string first` of an empty needle is -1, so it cannot
## be passed through).  ONE gate run for the whole corpus.
proc problems_per_file {issuesdir baselinefile common pairs} {
    set p [with_corpus $issuesdir $baselinefile {istamp::gate}]
    set out {}
    foreach {num needle} $pairs {
        set n 0
        foreach x $p {
            if {![string match "${num}:*" $x] || [string first $common $x] < 0} { continue }
            if {$needle eq "" || [string first $needle $x] >= 0} { incr n }
        }
        lappend out $n
    }
    return $out
}

## ⚠ A QUOTE THE PARSER DOES NOT READ IS A NAMED PROBLEM, NEVER A SILENT PASS
## (outsider-fixes DECISIONS D15).  S1-fix3's refuter MEASURED a rotted quote=
## passing `ok (0 problems)` in three forms -- an indented fence (two spaces:
## CommonMark renders it as code), a ~~~ fence, and a fence left open at the end
## of the file -- while the same block at column 0 was red.  Each is planted
## here with a ROTTED body, plus two more the parser misses the same way (a fence
## inside another block, where it is text, and one in a blockquote) and a quote
## in a file with no stamp at all, where no quote is ever verified.  Each must be
## a problem naming its cause.  The last file is the known NEGATIVE, 0993's
## shape: `quote=` in prose and inside code is not an attribute, and a check
## that fired on it would redden a corpus it has no business reading.
## Text-only, so it runs in every state: the problems are reported before the
## revision question, even where tree= cannot be asked or is refused.
check "Q3 RED: a quote= the parser does not read -- indented, ~~~, never closed, inside another block, in a blockquote, in an unstamped file -- is a named problem; quote= in prose or code is not" \
    [set q3s "**STAMP:** `v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=0`" ;
     set q3o "quote=$REV path=tests/banner_rule.tcl" ;
     set q3r "Tcl_SetResult(interp, \"q3 text that was never in any revision\", TCL_VOLATILE);" ;
     lassign [mkcorpus strayquote [list \
         9001-x.md "# 9001 - x\n\n$q3s\n\n  ```c $q3o\n  $q3r\n  ```" \
         9002-x.md "# 9002 - x\n\n$q3s\n\n~~~c $q3o\n$q3r\n~~~" \
         9003-x.md "# 9003 - x\n\n$q3s\n\n```c $q3o\n$q3r" \
         9004-x.md "# 9004 - x\n\n$q3s\n\n```text\n```c $q3o\n$q3r\n```" \
         9005-x.md "# 9005 - x\n\n$q3s\n\n> ```c $q3o\n> $q3r\n> ```" \
         9006-x.md "# 9006 - x, grandfathered\n\n```c $q3o\n$q3r\n```" \
         9007-x.md "# 9007 - x\n\n$q3s\n\nThe C reads (`if(c=='\"' && !escape) quote=!quote;`).\n\n```c\nif (c) quote=!quote;\n```"] "9006-x.md"] id bf ;
     problems_per_file $id $bf "a quote= the parser does not read" \
         {9001 indented 9002 ~~~ 9003 "never closed" 9004 "inside another fenced block" 9005 blockquote 9006 "no **STAMP:** line" 9007 {}}] \
    {1 1 1 1 1 1 0}

## ⚠ AND A STAMP THE PARSER DOES NOT READ, THE SAME WAY.  find_stamp reads
## `**STAMP:**` at column 0 and nothing else, so a stamp written under an indent,
## in a blockquote, in a list item or spelled `**stamp:**` was never read: in a
## grandfathered file nothing it states was checked, and the file passed as if
## unconverted.  Each is planted, three of them in grandfathered files and one in
## a NEW file (which is also red for having no stamp -- counted separately
## here).  The last file is the known NEGATIVE: S16's mid-sentence mention, and
## 1317's `**Stamp the record** with a token` -- prose, and not a problem.
check "Q4 RED: a **STAMP:** line the parser does not read -- indented, in a blockquote, in a list item, misspelled -- is a named problem; a stamp mentioned in prose is not" \
    [set q4b "`v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=0`" ;
     lassign [mkcorpus straystamp [list \
         9011-x.md "# 9011 - x\n\n  **STAMP:** $q4b" \
         9012-x.md "# 9012 - x\n\n> **STAMP:** $q4b" \
         9013-x.md "# 9013 - x\n\n**stamp:** $q4b" \
         9014-x.md "# 9014 - x\n\n- **STAMP:** $q4b" \
         9015-x.md "# 9015 - x\n\n**STAMP:** $q4b\n\n# see **STAMP:** `v1 ...` in the spec\n\n1. **Stamp the record** with a token."] "9011-x.md\n9013-x.md\n9014-x.md"] id bf ;
     problems_per_file $id $bf "a **STAMP:** line the parser does not read" \
         {9011 indented 9012 blockquote 9013 "not spelled exactly" 9014 "list item" 9015 {}}] \
    {1 1 1 1 0}

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

## (It matched "grep failed*" until D16: there is no grep any more -- the search
## is Tcl -- and a detail naming a program that never ran would be the lying
## detail string this batch keeps finding.)
check "A5 an assertion that cannot be evaluated is a named outcome, never a silent pass" \
    [lassign [istamp::assert_eval absent x no/such/path/at/all] holds hits why ;
     list $holds [string match "path=no/such/path/at/all does not exist*" $why]] \
    {-1 1}

## Point the checker's repository at a PLAIN directory -- no git in it -- for
## the length of $body, with history `none`, so the gate asks git nothing and
## an assert= block is evaluated against that directory.  This is how the rows
## below plant hostile assert= blocks WITHOUT naming a single file of the real
## checkout: every path they give is inside this run's scratch, so even a
## regressed checker that executed them again could damage nothing but scratch.
proc with_plain_root {dir body} {
    set saved [list $istamp::repo $istamp::history]
    set istamp::repo    [file normalize $dir]
    set istamp::history [dict create state none why "a plain scratch directory (a test fixture)"]
    set rc [catch {uplevel 1 $body} res opt]
    lassign $saved istamp::repo istamp::history
    if {$rc} { return -options $opt $res }
    return $res
}

## Everything under $dir, as {relative-name size} pairs, sorted -- the "did
## anything get written?" evidence.  Links are listed, not followed.
proc istamp_listing {dir} {
    set out {}
    set todo [list $dir]
    while {[llength $todo]} {
        set d [lindex $todo 0]
        set todo [lrange $todo 1 end]
        foreach p [concat [glob -nocomplain -directory $d *] [glob -nocomplain -directory $d -types hidden *]] {
            set b [string range $p [expr {[string last / $p] + 1}] end]
            if {$b in {. ..}} { continue }
            if {[catch {file lstat $p st}]} { continue }
            lappend out [list [string range $p [expr {[string length $dir] + 1}] end] $st(type) $st(size)]
            if {$st(type) eq "directory"} { lappend todo $p }
        }
    }
    return [lsort $out]
}

## The fixture for Q5 and Q6: a plain "checkout" ck/ and a directory BESIDE it,
## out/, standing for everything outside the checkout.  Built once.
##   ck/victim.txt   six lines, each carrying one of the redirection tokens
##   ck/mark.sh      executable; if anything ever RUNS it, it writes out/ran
##   out/tok.txt     OUTSIDETOKEN -- found only if something reads outside ck
##   ck/lnkdir, lnkfile, lnkrel   symbolic links from inside ck to out/
##   ck/scan/        real.txt, .hidden.txt and ~nosuchuser/t2.txt (OUTSIDETOKEN
##                   each: a hidden file is read, and a child called `~name` is
##                   a name -- `file join` would make it a home lookup), plus
##                   esc -> out/, which grep -r does not follow
##   ck/lnkin        a symbolic link to victim.txt, INSIDE ck: allowed
##   ck/~x/t.txt     a directory literally called ~x: never a home lookup
##   ck/bin/b1.dat   OUTSIDETOKEN after a NUL byte: a binary file that matches
set IJ_ROOT [istamp_own [file join $::ISTAMP_SCRATCH_ROOT istamp_[pid]_inject]]
set IJ_CK   [file join $IJ_ROOT ck]
set IJ_OUT  [file join $IJ_ROOT out]
set IJ_ERR  ""
if {[catch {
        file delete -force $IJ_ROOT
        file mkdir $IJ_CK $IJ_OUT [file join $IJ_CK scan] "$IJ_CK/~x" "$IJ_CK/scan/~nosuchuser" [file join $IJ_CK bin]
        set fh [open [file join $IJ_CK scan .hidden.txt] w] ; puts $fh "OUTSIDETOKEN, hidden" ; close $fh
        set fh [open "$IJ_CK/scan/~nosuchuser/t2.txt" w] ; puts $fh "OUTSIDETOKEN, under ~nosuchuser" ; close $fh
        set fh [open [file join $IJ_CK bin b1.dat] w] ; fconfigure $fh -translation binary
        puts -nonewline $fh "abc\x00def OUTSIDETOKEN\n" ; close $fh
        set fh [open [file join $IJ_CK victim.txt] w]
        puts $fh "redirect: a > b\nquiet: cmd 2>/dev/null\nquiet again: cmd2 2>/dev/null\npipe: x | y\nmerge: 2>&1\nlt: a < b"
        close $fh
        set fh [open [file join $IJ_CK mark.sh] w]
        puts $fh "#!/bin/sh\necho ran > [file join $IJ_OUT ran]"
        close $fh
        file attributes [file join $IJ_CK mark.sh] -permissions 0755
        set fh [open [file join $IJ_OUT tok.txt] w] ; puts $fh "OUTSIDETOKEN, outside the checkout" ; close $fh
        set fh [open [file join $IJ_CK scan real.txt] w] ; puts $fh "OUTSIDETOKEN, inside the checkout" ; close $fh
        set fh [open "$IJ_CK/~x/t.txt" w] ; puts $fh "OUTSIDETOKEN, in a directory called ~x" ; close $fh
        file link -symbolic [file join $IJ_CK lnkdir]  $IJ_OUT
        file link -symbolic [file join $IJ_CK lnkfile] [file join $IJ_OUT tok.txt]
        file link -symbolic [file join $IJ_CK lnkrel]  ../out
        file link -symbolic [file join $IJ_CK scan esc] $IJ_OUT
        file link -symbolic [file join $IJ_CK lnkin]   victim.txt
    } e]} {
    set IJ_ERR [lindex [split $e \n] 0]
}

## ⚠ D16.1 -- AN assert= PATTERN IS A LITERAL, AND NOTHING RUNS.  The checker ran
## `exec ... grep -rn -- $pat $target`, and Tcl's exec reads a word beginning
## with `>`, `2>`, `<` or `|` as a redirection or a pipe, `--` or no `--`.
## MEASURED red-first (S1-fix5, S1-fix4's bytes, a scratch clone): `pat=>`
## truncated README to 0 bytes; `pat=2>` overwrote it; `pat=|` RAN the script
## path= named; `pat=>/elsewhere/pwned` wrote a file outside the checkout with
## the gate `ok` and the suite ALL PASS; `pat=2>/dev/null` turned a FALSE
## assertion green; `pat=2>&1` left `&1` in the cwd.  Each recipe is planted here
## against a scratch "checkout", and must be counted as the literal text it is --
## the lines of victim.txt that contain it, known by construction:
##     >  4     2>  3     |  1     >out/pwned  0     2>/dev/null  2     2>&1  1     <  1
## and `pat=|` against mark.sh, whose text has no `|`: 0.  Then the gate, on a
## stamped file declaring `assert=absent pat=2>/dev/null ... state=holds`: that is
## FALSE, and must be RED.  Then the evidence that nothing was written or run:
## victim.txt byte-identical, nothing new under ck/ or out/ (no `ran`, no
## `pwned`), and no `&1` appeared in the cwd.
check "Q5 RED/GREEN: assert= patterns that are redirections or pipes to Tcl's exec -- >, 2>, |, >file, 2>/dev/null, 2>&1, < -- are counted as literal text, a false one is RED, and nothing is written or run" \
    [if {$IJ_ERR ne ""} {
         set q5 "FIXTURE NOT BUILT: $IJ_ERR"
     } else {
         set q5_before [istamp_listing $IJ_ROOT]
         set q5_vict   [istamp::read_file [file join $IJ_CK victim.txt]]
         set q5_amp    [file exists [file join [pwd] &1]]
         set q5_pw     [file join $IJ_OUT pwned]
         set q5_hits {}
         with_plain_root $IJ_CK {
             foreach {p f} [list > victim.txt 2> victim.txt | victim.txt >$q5_pw victim.txt \
                                 2>/dev/null victim.txt 2>&1 victim.txt < victim.txt | mark.sh] {
                 lassign [istamp::assert_eval absent $p $f] h n w
                 lappend q5_hits [expr {$h == -1 ? "ERR: $w" : $n}]
             }
             ## The `>file` recipe in the CORPUS names its target RELATIVE to ck/,
             ## and the gate runs with ck/ as the working directory: an issue
             ## file's pat= is one whitespace-free token (D19 reads the info string
             ## in full), and this checkout's own path may hold a space -- in the
             ## stranger shape `we ird[x] %41/xschem` the absolute spelling was two
             ## words, named as a malformed fence, and this row went red for a tree
             ## that is fine (MEASURED, S1-fix7).  A regressed checker that ran the
             ## word as a redirection would still write out/pwned, inside scratch.
             lassign [mkcorpus q5gate [list 9999-x.md "# 9999 - x\n\n**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=0`\n\n```sh assert=absent pat=2>/dev/null path=victim.txt state=holds\nx\n```\n\n```sh assert=absent pat=>../out/pwned path=victim.txt state=holds\nx\n```\n\n```sh assert=absent pat=| path=mark.sh state=holds\nx\n```"] ""] id bf
             set q5_cwd [pwd]
             cd $IJ_CK
             set q5_rc [catch {
                 set q5_red [problems_matching $id $bf "HOLDS and it does not (2 hits for 2>/dev/null"]
                 set q5_all [llength [with_corpus $id $bf {istamp::gate}]]
             } q5_e]
             cd $q5_cwd
             if {$q5_rc} { error $q5_e }
         }
         set q5_clean [expr {[istamp_listing $IJ_ROOT] eq $q5_before
                             && [istamp::read_file [file join $IJ_CK victim.txt]] eq $q5_vict
                             && [file exists [file join [pwd] &1]] == $q5_amp}]
         set q5 [list $q5_hits $q5_red $q5_all $q5_clean]
     } ; set q5] \
    {{4 3 1 0 2 1 1 0} 1 1 1}

## One assert_eval answer as a word: the hit count, or which named outcome.
proc q6_status {h n w} {
    if {$h != -1}                                     { return $n }
    if {[string match "path=* is refused: *" $w]}     { return refused }
    if {[string match "* does not exist*" $w]}        { return missing }
    if {[string match "* is a binary file *" $w]}     { return binary }
    if {[string match "the search ran past its *" $w]} { return budget }
    return "OTHER: $w"
}

## ⚠ D16.2 -- path= STAYS INSIDE THE CHECKOUT, AND NOTHING OUTSIDE IS READ.  It
## was `[file join $repo $path]` handed to grep, so an absolute path, a `..`
## component and a symbolic link out of the checkout all read files anywhere --
## MEASURED red-first (S1-fix5): a token in a directory beside a scratch clone
## was FOUND through each of them, and `path=../<script>` with `pat=|` RAN it.
## Refused here, each by name: absolute, `..` (twice), a leading `-`, empty, and
## four ways a symbolic link leads out (to a directory, to a file, relative, and
## as a middle component).  ⚠ out/ is made UNREADABLE for the length of the
## row: a checker that looked at anything beyond the checkout before refusing
## would answer "cannot look at" instead of "refused".  The known POSITIVES: a
## directory is searched with its hidden file and its `~nosuchuser` child read
## and the link inside it NOT followed (scan: 3, as grep -r), a link that stays
## inside is followed (lnkin: 2), `~x` is a directory called ~x (1), and a path
## that is not there is "does not exist", not refused.  Then what grep 3.12
## could not count, still uncounted and named: a binary file that matches
## (binary), while one that does not is simply 0; and a search past its budget
## (t_scan set below zero for one call) is named, not silently short.  The gate
## names a refusal as a problem.
check "Q6 RED: an assert= path= that leaves the checkout -- absolute, .., a leading -, empty, or a symbolic link out of it -- is refused by name and nothing outside is read; a link that stays inside is followed, one below path= is not" \
    [if {$IJ_ERR ne ""} {
         set q6 "FIXTURE NOT BUILT: $IJ_ERR"
     } else {
         set q6 {}
         catch {file attributes $IJ_OUT -permissions 0000}
         set q6_rc [catch {
             with_plain_root $IJ_CK {
                 foreach {p f} [list OUTSIDETOKEN $IJ_OUT OUTSIDETOKEN ../out OUTSIDETOKEN scan/../../out \
                                     OUTSIDETOKEN -x OUTSIDETOKEN {} OUTSIDETOKEN lnkdir \
                                     OUTSIDETOKEN lnkfile OUTSIDETOKEN lnkrel OUTSIDETOKEN lnkdir/tok.txt \
                                     OUTSIDETOKEN scan 2>/dev/null lnkin OUTSIDETOKEN ~x OUTSIDETOKEN nosuch] {
                     lassign [istamp::assert_eval present $p $f] h n w
                     lappend q6 [q6_status $h $n $w]
                 }
                 lassign [istamp::assert_eval present OUTSIDETOKEN bin] h n w ; lappend q6 [q6_status $h $n $w]
                 lassign [istamp::assert_eval present ZZNOTHERE bin] h n w    ; lappend q6 [q6_status $h $n $w]
                 set q6_budget $istamp::t_scan
                 set istamp::t_scan -1
                 set q6_rb [catch {istamp::assert_eval present OUTSIDETOKEN scan} q6_b]
                 set istamp::t_scan $q6_budget
                 if {$q6_rb} { lappend q6 "DIED: $q6_b" } else { lassign $q6_b h n w ; lappend q6 [q6_status $h $n $w] }
                 lassign [mkcorpus q6gate [list 9999-x.md "# 9999 - x\n\n**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=0`\n\n```sh assert=present pat=OUTSIDETOKEN path=lnkdir state=holds\nx\n```"] ""] id bf
                 lappend q6 [problems_matching $id $bf "path=lnkdir is refused: it leaves the checkout through a symbolic link"]
             }
         } q6_err]
         catch {file attributes $IJ_OUT -permissions 0755}
         if {$q6_rc} { set q6 "ROW DIED: [lindex [split $q6_err \n] 0]" }
     } ; set q6] \
    {refused refused refused refused refused refused refused refused refused 3 2 1 missing binary 0 budget 1}

## ⚠ D16.5 -- A STAMP IS RECOGNISED BY WHAT IT SAYS, NOT BY ONE SPELLING OF BOLD.
## The unread-stamp detector matched only `**`.  S1-fix4's refuter planted
## `__STAMP:__`, `<strong>STAMP:</strong>` and `<b>STAMP:</b>` -- markdown-it
## renders each to the same HTML as `**STAMP:**` -- naming a bogus tree= in a
## grandfathered file, and each passed `ok (0 problems)`; MEASURED red-first by
## S1-fix5, together with a plain `STAMP: `v1 ...`` and `**STAMP**:`.  Each must be
## one named problem.  The last file is the known NEGATIVE: a word that ends in
## "stamp", a "Stamp:" that is not followed by a stamp's body, and S16's
## mid-sentence mention -- prose, all of it.  Text only: it runs in every state.
check "Q8 RED: a stamp in another spelling -- __STAMP:__, <strong>, <b>, plain STAMP: `v1, **STAMP**: -- is a named problem; prose that mentions a stamp is not" \
    [set q8b "`v1 claim=fixed tree=deadbee0 stamped=2026-09-17 fix=taken open=0`" ;
     lassign [mkcorpus straystamp2 [list \
         9021-x.md "# 9021 - x\n\n__STAMP:__ $q8b" \
         9022-x.md "# 9022 - x\n\n<strong>STAMP:</strong> $q8b" \
         9023-x.md "# 9023 - x\n\n<b>STAMP:</b> $q8b" \
         9024-x.md "# 9024 - x\n\nSTAMP: $q8b" \
         9025-x.md "# 9025 - x\n\n**STAMP**: $q8b" \
         9026-x.md "# 9026 - x\n\nTimestamp: 2026-09-18\n\nStamp: the v2 layout, below.\n\nsee **STAMP:** `v1 ...` mid-sentence"] \
         "9021-x.md\n9022-x.md\n9023-x.md\n9024-x.md\n9025-x.md\n9026-x.md"] id bf ;
     problems_per_file $id $bf "a **STAMP:** line the parser does not read" \
         {9021 "not spelled exactly" 9022 "not spelled exactly" 9023 "not spelled exactly" \
          9024 "not spelled exactly" 9025 "not spelled exactly" 9026 {}}] \
    {1 1 1 1 1 0}

## ---------------------------------------------------------------------------
## D18 -- the checker's threat model: SAFETY on any corpus, honest mistakes
## FAIL-CLOSED, strangers never falsely red.  Deliberate DISGUISE of a stamp
## (NBSP, ZWSP, HTML with attributes, a table, a link, a task list) is OUT OF
## SCOPE and has no row: whoever can write the issue file can leave the stamp
## out.  The four rows below are what S1-fix5's refuter found INSIDE the model.
## ---------------------------------------------------------------------------

## The fixture for Q9: a plain "checkout" whose enc/ holds names that are NOT
## valid UTF-8, made in bytes (istamp::in_bytes), each file holding ENCTOKEN on
## a known number of lines -- 5 in all, what `grep -rnF ENCTOKEN enc` counts:
##   enc/caf\xe9/note.txt    2 lines   a Latin-1 e-acute: not UTF-8
##   enc/\xff\xfe.txt        1 line    two bytes no UTF-8 text contains
##   enc/café-utf8/n.txt     1 line    the same word in UTF-8: valid
##   enc/plain.txt           1 line
## Made with the suite's OWN switch to iso8859-1 (every byte one character),
## not the checker's in_bytes -- the fixture must not depend on the code under
## test -- and the encoding is put back whatever happens.
set IJE_ROOT [istamp_own [file join $::ISTAMP_SCRATCH_ROOT istamp_[pid]_enc]]
set IJE_ERR ""
catch {file delete -force $IJE_ROOT}
set IJE_B [encoding convertfrom iso8859-1 [encoding convertto [encoding system] $IJE_ROOT]]
set IJE_ENC [encoding system]
encoding system iso8859-1
if {[catch {
        file mkdir "$IJE_B/enc/caf\xe9" "$IJE_B/enc/caf\xc3\xa9-utf8"
        foreach {f body} [list "$IJE_B/enc/caf\xe9/note.txt" "ENCTOKEN one\nnothing\nENCTOKEN two ENCTOKEN\n" \
                               "$IJE_B/enc/\xff\xfe.txt" "ENCTOKEN three\n" \
                               "$IJE_B/enc/caf\xc3\xa9-utf8/n.txt" "ENCTOKEN four\n" \
                               "$IJE_B/enc/plain.txt" "ENCTOKEN five\n"] {
            set fh [open $f w] ; fconfigure $fh -translation binary ; puts -nonewline $fh $body ; close $fh
        }
    } e]} {
    set IJE_ERR [lindex [split $e \n] 0]
}
encoding system $IJE_ENC

## One assert_eval under a forced system encoding -- utf-8 is this box's
## LANG=C.UTF-8, iso8859-1 is Tcl's under LANG=C -- as the hit count, a named
## outcome, or the encoding the scan failed to put back.  The checker's root is
## re-read as that locale would have decoded it (the same bytes, the other
## encoding), so a checkout under a non-ASCII directory is emulated honestly
## instead of being handed a root spelled for the wrong locale.
proc q9_in {enc path} {
    return [encoding convertfrom $enc [encoding convertto [encoding system] $path]]
}
proc q9_eval {enc kind pat path} {
    set old [encoding system]
    set saved $istamp::repo
    set istamp::repo [q9_in $enc $saved]
    encoding system $enc
    set rc [catch {istamp::assert_eval $kind $pat $path} r]
    set after [encoding system]
    encoding system $old
    set istamp::repo $saved
    if {$rc} { return "DIED: [lindex [split $r \n] 0]" }
    if {$after ne $enc} { return "ENCODING LEFT AS $after" }
    lassign $r h n w
    return [expr {$h == -1 ? "ERR: $w" : $n}]
}

## ⚠ D18 -- A NAME THAT IS NOT UTF-8 IS STILL SEARCHED, IN EVERY LOCALE.  The
## Tcl scan that replaced grep (D16) skipped any entry whose name did not
## round-trip through the system encoding, WITHOUT A WORD.  MEASURED by
## S1-fix5's refuter and again red-first by S1-fix6 in a scratch clone: a token
## only in src/caf\xe9/note.txt, and a FALSE `assert=absent ... path=src
## state=holds` was `ok (0 problems)` under LANG=C.UTF-8 and RED under LANG=C.
## Here, under BOTH encodings: the whole of enc/ counts 5, and path= naming the
## UTF-8 directory counts 1 -- path= is UTF-8 text, the corpus's encoding, so it
## names the same directory in every locale.  Then the FALLBACK: the scan's
## inner walk, handed the directory WITHOUT the bytes scope under utf-8 -- the
## S1-fix5 condition, rebuilt on purpose -- must NAME the entry it cannot look
## at, never skip it.  Then the gate: a stamped file declaring ENCTOKEN absent
## from enc/ is RED with all 5 hits.
check "Q9 RED: an assert= scan reads names that are not UTF-8 under utf-8 AND iso8859-1 (5 = grep -rnF), path= is UTF-8 in every locale, an entry it still cannot look at is NAMED, and a false assertion over them is RED" \
    [if {$IJE_ERR ne ""} {
         set q9 "FIXTURE NOT BUILT: $IJE_ERR"
     } else {
         set q9 {}
         with_plain_root $IJE_ROOT {
             foreach enc {utf-8 iso8859-1} {
                 lappend q9 [q9_eval $enc present ENCTOKEN enc]
                 lappend q9 [q9_eval $enc present ENCTOKEN "enc/caf\u00e9-utf8"]
             }
             set q9_old [encoding system]
             set q9_dir [q9_in utf-8 "$istamp::repo/enc"]
             encoding system utf-8
             set q9_rc [catch {istamp::scan_dir $q9_dir [encoding convertto utf-8 ENCTOKEN] [expr {[clock milliseconds] + 60000}]} q9_fb]
             encoding system $q9_old
             lappend q9 [expr {$q9_rc && [string match "cannot look at `*`, which its directory lists*" $q9_fb] ? "named" : "NOT NAMED: rc=$q9_rc [string range $q9_fb 0 99]"}]
             lassign [mkcorpus q9gate [list 9999-x.md "# 9999 - x\n\n**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=0`\n\n```sh assert=absent pat=ENCTOKEN path=enc state=holds\nx\n```"] ""] id bf
             lappend q9 [problems_matching $id $bf "HOLDS and it does not (5 hits for ENCTOKEN"]
         }
     } ; set q9] \
    {5 1 5 1 named 1}

## ⚠ D18 -- AN assert= THE PARSER DOES NOT READ IS NAMED, AS A quote= IS (D15).
## Only quote= was named, so a FALSE assertion (SABOTAGE, eight real hits under
## src, declared absent) went `ok (0 problems)` in each place below while the
## same block at column 0 was RED -- MEASURED by S1-fix5's refuter (six
## places) and red-first by S1-fix6 (seven, adding a fence inside another
## block).  Each must be one problem naming its cause, the unstamped file's
## included: an assert= in a file with no stamp is never evaluated.  The last
## file is the known NEGATIVE: a READ assert= that holds, and assert= in prose.
## Text-only, so it runs in every state.
check "Q10 RED: an assert= the parser does not read -- ~~~, indented, blockquote, list item, never closed, inside another block, not lowercase, in an unstamped file -- is a named problem; a read assert= and assert= in prose are not" \
    [set q10s "**STAMP:** `v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=0`" ;
     set q10a "assert=absent pat=SABOTAGE path=src state=holds" ;
     lassign [mkcorpus strayassert [list \
         9031-x.md "# 9031 - x\n\n$q10s\n\n~~~sh $q10a\nx\n~~~" \
         9032-x.md "# 9032 - x\n\n$q10s\n\n  ```sh $q10a\n  x\n  ```" \
         9033-x.md "# 9033 - x\n\n$q10s\n\n> ```sh $q10a\n> x\n> ```" \
         9034-x.md "# 9034 - x\n\n$q10s\n\n1. ```sh $q10a\n   x\n   ```" \
         9035-x.md "# 9035 - x\n\n$q10s\n\n```sh $q10a\nx" \
         9036-x.md "# 9036 - x\n\n$q10s\n\n````text\n```sh $q10a\nx\n```\n````" \
         9037-x.md "# 9037 - x\n\n$q10s\n\n```sh ASSERT=absent pat=SABOTAGE path=src state=holds\nx\n```" \
         9038-x.md "# 9038 - x, grandfathered\n\n```sh $q10a\nx\n```" \
         9039-x.md "# 9039 - x\n\n$q10s\n\nThe gate reads assert=absent in a fence, never in prose.\n\n```sh assert=absent pat=ZZQQNOSUCHTOKENZZ path=src state=holds\nx\n```"] "9038-x.md"] id bf ;
     problems_per_file $id $bf "an assert= the parser does not read" \
         {9031 "~~~" 9032 indented 9033 blockquote 9034 "list item" 9035 "never closed" \
          9036 "inside another fenced block" 9037 "not written" 9038 "no **STAMP:** line" 9039 {}}] \
    {1 1 1 1 1 1 1 1 0}

## ⚠ D18 -- AN ISSUE FILE, OR THE BASELINE, THAT IS NOT A REGULAR FILE IS NAMED
## AND NEVER OPENED.  MEASURED by S1-fix5's refuter and red-first by S1-fix6: an
## issue file that was a symbolic link OUT of the checkout was read (its planted
## stamp checked), one that was a link to a FIFO -- or a FIFO, or a FIFO
## baseline -- blocked the gate in `open` until an external timeout killed it.
## In process: a link out (to a file whose stamp names deadbee0 -- and no
## problem may mention deadbee0, since nothing may read it), a link to a
## sibling inside the corpus, a dangling link, and a regular stamped file (the
## known NEGATIVE); then a baseline that is a link; then a checkout whose
## doc/claude/issues is itself a link out, one level up.  The FIFOs are asked in a
## CHILD tclsh under `timeout`, so a regressed checker makes this row red, by
## name, instead of hanging the suite that is checking it: a FIFO, a link to
## one, and a FIFO baseline, each named.
check "Q11 RED: an issue file that is a symbolic link (out, inside, dangling) or a FIFO, and a baseline that is a link or a FIFO, is a named problem and is never opened -- nothing outside is read, and nothing blocks" \
    [lassign [mkcorpus nonreg [list 9043-x.md "# 9043 - x\n\n**STAMP:** `v1 claim=open tree=$REV stamped=2026-09-17 fix=none open=0`"] ""] id bf ;
     set q11d [file dirname $id] ;
     set q11 {} ;
     if {[catch {
             set fh [open [file join $q11d outside.md] w]
             puts $fh "# outside\n\n**STAMP:** `v1 claim=open tree=deadbee0 stamped=2026-09-17 fix=none open=0`"
             close $fh
             file link -symbolic [file join $id 9041-x.md] [file join $q11d outside.md]
             file link -symbolic [file join $id 9042-x.md] 9043-x.md
             ## Tcl refuses a link to a target that does not exist, so the
             ## dangling one is made to a file that is then deleted.
             close [open [file join $q11d gone.md] w]
             file link -symbolic [file join $id 9044-x.md] [file join $q11d gone.md]
             file delete [file join $q11d gone.md]
         } q11e]} {
         set q11 "FIXTURE NOT BUILT: [lindex [split $q11e \n] 0]"
     } else {
         set q11p [with_corpus $id $bf {istamp::gate}]
         foreach n {9041 9042 9043 9044} {
             set c 0
             foreach x $q11p { if {[string match "$n (*): is a symbolic link*not a regular file*" $x]} { incr c } }
             lappend q11 $c
         }
         set c 0 ; foreach x $q11p { if {[string first deadbee0 $x] >= 0} { incr c } } ; lappend q11 $c
         file rename $bf $bf.real
         file link -symbolic $bf $bf.real
         lappend q11 [string match "BASELINE UNUSABLE: * is a symbolic link*" [lindex [with_corpus $id $bf {istamp::gate}] 0]]
         file delete $bf
         file rename $bf.real $bf
         ## The corpus DIRECTORY, one level up: a plain checkout whose
         ## doc/claude/issues is a link to a directory beside it holding a
         ## file whose stamp names deadbee0.  Named, and nothing in it read.
         set q11r [file join $q11d ck]
         file mkdir [file join $q11d outside_issues] [file join $q11r doc claude]
         set fh [open [file join $q11d outside_issues 9047-x.md] w]
         puts $fh "# 9047 - outside\n\n**STAMP:** `v1 claim=open tree=deadbee0 stamped=2026-09-17 fix=none open=0`"
         close $fh
         file link -symbolic [file join $q11r doc claude issues] [file join $q11d outside_issues]
         set q11dp [with_plain_root $q11r {with_corpus [file join $istamp::repo doc claude issues] $bf {istamp::gate}}]
         lappend q11 [expr {[llength $q11dp] == 1 && [string match "CORPUS OUTSIDE THE CHECKOUT: *" [lindex $q11dp 0]]}]
         ## The FIFO half, in a child.  Its paths are this run's scratch; the
         ## FIFOs are made by `mkfifo` under `timeout`, never from corpus text.
         set q11f [file join $q11d fifo_issues]
         set q11fb [file join $q11d fifo_baseline.txt]
         set q11drv [file join $q11d drv.tcl]
         if {[catch {
                 file mkdir $q11f
                 exec timeout 10 mkfifo -- [file join $q11f 9045-x.md] [file join $q11d the_fifo] $q11fb
                 file link -symbolic [file join $q11f 9046-x.md] [file join $q11d the_fifo]
                 set fh [open $q11drv w]
                 puts $fh {set ::ISSUE_STAMP_LIB 1}
                 puts $fh [list source [file join [file dirname [file normalize [info script]]] issue_stamp.tcl]]
                 puts $fh {set istamp::history [dict create state none why "a fixture"]}
                 puts $fh [list set istamp::issues_dir $q11f]
                 puts $fh [list set istamp::baseline $bf]
                 puts $fh {set p [istamp::gate] ; set a 0 ; set b 0}
                 puts $fh {foreach x $p { if {[string match "9045 (*): is a fifo, not a regular file*" $x]} { incr a } ; if {[string match "9046 (*): is a symbolic link*" $x]} { incr b } }}
                 puts $fh [list set istamp::baseline $q11fb]
                 puts $fh {puts "$a $b [string match {BASELINE UNUSABLE: * is a fifo, not a regular file*} [lindex [istamp::gate] 0]]"}
                 close $fh
             } q11e]} {
             lappend q11 "FIFO FIXTURE NOT BUILT: [lindex [split $q11e \n] 0]"
         } elseif {[catch {exec timeout 60 tclsh $q11drv} q11out q11opt]} {
             set q11ec [dict get $q11opt -errorcode]
             if {[lindex $q11ec 0] eq "CHILDSTATUS" && [lindex $q11ec 2] == 124} {
                 lappend q11 "TIMED OUT: the gate blocked on a FIFO"
             } else {
                 lappend q11 "DRIVER DIED: [lindex [split $q11out \n] 0]"
             }
         } else {
             lappend q11 [string trim $q11out]
         }
     } ; set q11] \
    {1 1 0 1 0 1 1 {1 1 1}}

## ⚠ D18 -- STRIPPING MARKDOWN'S CONTAINERS COSTS ONE PASS, NOT ONE PASS PER
## MARKER.  md_strip copied the rest of the line once per marker it removed:
## MEASURED by S1-fix5's refuter, three lines of 50k `>` took the gate from
## 0.6 s to 19.2 s, in a busy Tcl loop nothing can interrupt; red-first by
## S1-fix6, the CLI took 22 s for that file, 20 s for `>`-runs ending in the
## bare word "stamp", and 6.6 s for three lines of 20k `- `.  The same three
## files here must be read in well under 2 s, and still NAME the three
## blockquoted and three list-item stamps (the bare word names nothing).
check "Q12 lines of 50k '>' and 20k '- ' markers cost one pass: three files of them are gated in under 2 s, and the stamps inside them are still named" \
    [set q12b "**STAMP:** `v1 claim=fixed tree=deadbee0 stamped=2026-09-17 fix=taken open=0`" ;
     set q12gt [string repeat > 50000] ;
     set q12da [string repeat {- } 20000] ;
     lassign [mkcorpus longlines [list \
         9051-x.md "# 9051 - x\n\n$q12gt $q12b\n$q12gt $q12b\n$q12gt $q12b" \
         9052-x.md "# 9052 - x\n\n$q12da$q12b\n$q12da$q12b\n$q12da$q12b" \
         9053-x.md "# 9053 - x\n\n${q12gt}stamp\n${q12gt}stamp\n${q12gt}stamp"] "9051-x.md\n9052-x.md\n9053-x.md"] id bf ;
     set q12t0 [clock milliseconds] ;
     set q12p [problems_per_file $id $bf "a **STAMP:** line the parser does not read" {9051 blockquote 9052 "list item" 9053 {}}] ;
     set q12ms [expr {[clock milliseconds] - $q12t0}] ;
     list {*}$q12p [expr {$q12ms < 2000 ? "fast" : "SLOW: $q12ms ms"}]] \
    {3 3 0 fast}

## ---------------------------------------------------------------------------
## D19 -- what S1-fix6's refuter found still inside the threat model (D18):
## readers that ignored the corpus confinement (A), a partial clone fetching
## because of corpus text (A), no total bound on assert= scans (A), and three
## honest mistakes passing green (B): a multi-word pat=, a stamp that lost its
## colon, and a new file under a grandfathered NUMBER.
## ---------------------------------------------------------------------------

## The fixture for Q13: two plain "checkouts" and, beside them, out/ standing
## for everything outside.
##   ck/doc/claude/issues/0001-a.md   unstamped, grandfathered   2 citations
##                        0002-b.md   stamped                    1 citation
##                        0003-l.md   -> out/o.md, a LINK: never opened, and a
##                                       link below the top is never walked
##                        0004_x.md   misnamed                   1 citation
##   ck/src/x.c                      3 citations
##   ck/src/bin.o                    a citation after a NUL byte: binary, 0
##   ck/src/esc  -> out/             never walked
##   ck/tests    -> out/             leads out: NOT COUNTED, by name
##   ck2/doc/claude/issues -> out/   the corpus directory itself leads out:
##                                   nothing listed, nothing counted
##   out/o.md       a stamp and 50 citations;  out/many.txt  100 citations;
##   out/9997-x.md  an issue file that exists only outside
set RP_ROOT [istamp_own [file join $::ISTAMP_SCRATCH_ROOT istamp_[pid]_rep]]
set RP_ERR ""
if {[catch {
        file delete -force $RP_ROOT
        set rpi [file join $RP_ROOT ck doc claude issues]
        set rpo [file join $RP_ROOT out]
        file mkdir $rpi [file join $RP_ROOT ck src] $rpo [file join $RP_ROOT ck2 doc claude]
        set rpst "**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=0`"
        foreach {f body} [list [file join $rpi 0001-a.md] "# 0001\n\nsee src/a.c:1 and src/b.h:22\n" \
                               [file join $rpi 0002-b.md] "# 0002\n\n$rpst\n\nsee src/c.tcl:3\n" \
                               [file join $rpi 0004_x.md] "# 0004\n\nsee x.sh:4\n" \
                               [file join $RP_ROOT ck src x.c] "/* a.c:1 b.h:2 c.py:3 */\n" \
                               [file join $rpo o.md] "# outside\n\n$rpst\n[string repeat "see o.c:1\n" 50]" \
                               [file join $rpo many.txt] [string repeat "see o.c:1\n" 100] \
                               [file join $rpo 9997-x.md] "# 9997 - only outside\n" \
                               [file join $RP_ROOT base.txt] "0001-a.md\n"] {
            set fh [open $f w] ; fconfigure $fh -encoding utf-8 ; puts -nonewline $fh $body ; close $fh
        }
        set fh [open [file join $RP_ROOT ck src bin.o] w] ; fconfigure $fh -translation binary
        puts -nonewline $fh "abc\x00 d.c:9\n" ; close $fh
        file link -symbolic [file join $rpi 0003-l.md] [file join $rpo o.md]
        file link -symbolic [file join $RP_ROOT ck src esc] $rpo
        file link -symbolic [file join $RP_ROOT ck tests] $rpo
        file link -symbolic [file join $RP_ROOT ck2 doc claude issues] $rpo
    } e]} {
    set RP_ERR [lindex [split $e \n] 0]
}

## ⚠ D19 -- `report` OBEYS THE RULES OF WHAT IS READ, AND NO ROW HELD IT BEFORE.
## It listed the corpus before asking issues_dir_problem and counted citations
## with a grep exec that follows a symbolic link on its command line: with
## doc/claude/issues a link out, it said `issue files: 0` while counting 5000
## citations planted outside (MEASURED by S1-fix6's refuter, red-first by
## S1-fix7; with src a link out, all 7000 of its "src" citations were outside).
## And sabotage REP -- report's regular-file check removed -- stayed ALL PASS,
## because nothing exercised report at all.  Now its census is asked for known
## answers: {files not-opened stamped misnamed grandfathered, citations in
## issues src tests, tests refused by name} in ck, then {files, CORPUS named,
## issues not counted} in ck2.  Nothing under out/ may be read or counted.
## Then THIS suite's own corpus reads, pointed at ck2: its B1 printed `9997`
## from outside the checkout in the refuter's recipe, so B1, B4 and the D9
## census must each answer NOT-READ, by name, and never mention 9997.
check_needs "Q13 report, and this suite's own corpus reads, read nothing outside the checkout: a linked issue file is not opened, a linked corpus directory is not listed, a directory that leads out is not counted -- and inside, the census's counts are the known ones" {
    if {$RP_ERR ne ""} {
        set r "FIXTURE NOT BUILT: $RP_ERR"
    } else {
        set a [with_plain_root [file join $RP_ROOT ck] {
            with_corpus [file join $istamp::repo doc claude issues] [file join $RP_ROOT base.txt] {istamp::report_census}
        }]
        set c [dict get $a cites]
        set r [list [list [dict get $a files] [dict get $a notopened] [dict get $a stamped] [dict get $a misnamed] \
                          [dict get $a baseline] [lindex [dict get $c doc/claude/issues] 0] [lindex [dict get $c src] 0] \
                          [lindex [dict get $c tests] 0] [string match "not counted: tests leads out of the checkout*" [lindex [dict get $c tests] 1]]]]
        set b [with_plain_root [file join $RP_ROOT ck2] {
            with_corpus [file join $istamp::repo doc claude issues] [file join $RP_ROOT base.txt] {istamp::report_census}
        }]
        lappend r [list [dict get $b files] [string match "CORPUS OUTSIDE THE CHECKOUT: *" [dict get $b corpus]] \
                        [lindex [dict get [dict get $b cites] doc/claude/issues] 0]]
        ## ...and THIS SUITE's own corpus reads -- B1, B4, the D9 census -- pointed
        ## at the same ck2: each NOT-READ by name, and none so much as names
        ## 9997, the issue file that exists only outside.
        set s [with_plain_root [file join $RP_ROOT ck2] {
            with_corpus [file join $istamp::repo doc claude issues] [file join $RP_ROOT base.txt] {
                list [istamp_b1_got] [istamp_b4_got] [istamp_d9_census]
            }
        }]
        lassign $s s1 s4 s9
        lappend r [list [expr {[lindex $s1 0] eq "NOT-READ"}] [expr {[lindex $s4 0] eq "NOT-READ"}] \
                        [expr {[lindex $s9 2] ne "" && ![llength [lindex $s9 0]]}] [expr {[string first 9997 $s] < 0}]]
    }
    set r
} {{3 1 1 1 1 4 3 -1 1} {0 1 -1} {1 1 1 1}}

## A plain "checkout" for Q14-Q16: t.txt holds `static int x;` and `static long
## y;`, so the phrase `static int` is on one line and `static` on two.
set RB_ROOT [istamp_own [file join $::ISTAMP_SCRATCH_ROOT istamp_[pid]_rb]]
set RB_ERR ""
if {[catch {
        file delete -force $RB_ROOT
        file mkdir $RB_ROOT
        set fh [open [file join $RB_ROOT t.txt] w] ; puts $fh "static int x;\nstatic long y;" ; close $fh
    } e]} {
    set RB_ERR [lindex [split $e \n] 0]
}
set RB_ST "**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=0`"

## ⚠ D19 -- A RUN'S assert= SCANS SHARE ONE CLOCK.  Each scan had its own 60 s,
## and nothing bounded how many: 100 two-line blocks over path=. held the CLI
## gate for 211 s (MEASURED by S1-fix6's refuter; 253.5 s red-first by
## S1-fix7), a busy Tcl loop nothing can interrupt.  Here the run's budget is
## set already spent (t_scan_total -1) for ONE gate over five blocks that would
## all hold: each is a problem naming the total budget, and nothing is scanned.
## Then the same five with the budget back: no problem at all -- so the budget,
## not the blocks, made the first answer -- and the run's deadline is cleared
## once the gate returns, so a scan outside a gate is never charged to it.
check_needs "Q14 a gate run's assert= scans share one budget: once it is spent every further block is a NAMED problem and nothing more is scanned; with the budget back the same blocks pass" {
    if {$RB_ERR ne ""} {
        set r "FIXTURE NOT BUILT: $RB_ERR"
    } else {
        set files {}
        foreach i {1 2 3 4 5} {
            lappend files 910$i-x.md "# 910$i - x\n\n$RB_ST\n\n```sh assert=absent pat=ZQXNOPE$i path=t.txt state=holds\nx\n```"
        }
        lassign [mkcorpus q14 $files ""] id bf
        with_plain_root $RB_ROOT {
            set q14_saved $istamp::t_scan_total
            set istamp::t_scan_total -1
            set q14_rc [catch {with_corpus $id $bf {istamp::gate}} q14_p]
            set istamp::t_scan_total $q14_saved
            set q14_cleared [expr {$istamp::scan_deadline eq ""}]
            set q14_back [with_corpus $id $bf {istamp::gate}]
        }
        if {$q14_rc} { error $q14_p }
        set n 0 ; foreach x $q14_p { if {[string match "91*: assertion could not be evaluated -- the search ran past the gate's total budget*" $x]} { incr n } }
        set r [list $n [llength $q14_p] [llength $q14_back] $q14_cleared]
    }
    set r
} {5 5 0 1}

## ⚠ D19 -- A MARKED FENCE'S INFO STRING IS READ IN FULL.  fence_scan kept the
## words shaped key=value and DROPPED the rest, so a malformed block was checked
## as a weaker claim: `pat="static int"` searched for `"static` (MEASURED by
## S1-fix6's refuter: the phrase is on 463 lines of src, and `ok (0 problems)`),
## and `pat=static nonexistent_zz_symbol` searched for `static`.  Each block
## below is FALSE as its author wrote it, or carries a word the grammar does not
## know; each must be one problem naming the fence, and not be evaluated.  The
## known NEGATIVES: a well-formed marked fence, and an ordinary code fence whose
## info string has words and no key=value at all (row N2's class).
check_needs "Q15 RED: a marked fence whose info string holds a word the grammar does not read -- a multi-word pat=, an unknown key, a key given twice, a stray word after a quote= -- is a named problem and is not evaluated; a well-formed one and an ordinary code fence are not" {
    if {$RB_ERR ne ""} {
        set r "FIXTURE NOT BUILT: $RB_ERR"
    } else {
        lassign [mkcorpus q15 [list \
            9111-x.md "# 9111 - x\n\n$RB_ST\n\n```sh assert=absent pat=\"static int\" path=t.txt state=holds\nx\n```" \
            9112-x.md "# 9112 - x\n\n$RB_ST\n\n```sh assert=present pat=static nonexistent_zz_symbol path=t.txt state=holds\nx\n```" \
            9113-x.md "# 9113 - x\n\n$RB_ST\n\n```sh assert=absent pat=ZQXNOPE path=t.txt state=holds pth=t.txt\nx\n```" \
            9114-x.md "# 9114 - x\n\n$RB_ST\n\n```sh assert=absent pat=ZQXNOPE pat=static path=t.txt state=holds\nx\n```" \
            9115-x.md "# 9115 - x\n\n$RB_ST\n\n```c quote=d64686a1 path=t.txt extra\nstatic int x;\n```" \
            9116-x.md "# 9116 - x\n\n$RB_ST\n\n```sh assert=absent pat=ZQXNOPE path=t.txt state=holds\nx\n```" \
            9117-x.md "# 9117 - x\n\n$RB_ST\n\n```text an ordinary title, with words\nstatic int x;\n```"] ""] id bf
        set r [with_plain_root $RB_ROOT {
            set p [with_corpus $id $bf {istamp::gate}]
            set out {}
            foreach n {9111 9112 9113 9114 9115 9116 9117} {
                set c 0 ; set all 0
                foreach x $p {
                    if {![string match "${n}:*" $x]} { continue }
                    incr all
                    if {[string first "a marked fence the parser cannot read in full" $x] >= 0} { incr c }
                }
                lappend out [list $c $all]
            }
            set out
        }]
    }
    set r
} {{1 1} {1 1} {1 1} {1 1} {1 1} {0 0} {0 0}}

## ⚠ D19 -- A LINE HOLDING A STAMP'S BODY IS NAMED, WHATEVER PRECEDES IT.  The
## stray-stamp detector needed the word and a COLON, so a stamp that lost its
## colon was prose: `**STAMP** `v1 claim=fixed tree=deadbee0 ...`` as a
## grandfathered file's line 3 said `ok (0 problems)`, and so did `STAMP`,
## `**Stamp**`, `**STAMP -**`, `**STAMP;**` and `**STAMP.**` (MEASURED by
## S1-fix6's refuter, red-first by S1-fix7).  Each is planted, plus a stamp
## quoted mid-sentence and a colon-less SECOND stamp under a stamped file's real
## one.  The known NEGATIVE: prose holding `v1` -- `v1 v2 v3`, a SPICE source
## `v1 = 8.3e-01`, a stamp mentioned as `v1 ...` -- all of which the real corpus
## has, and none of which is a body.
check_needs "Q16 RED: a line carrying a stamp's body that is not the stamp line the parser reads -- colon missing, **Stamp**, STAMP -, STAMP;, STAMP., mid-sentence, a second one -- is a named problem; prose holding v1 is not" {
    set q16b "`v1 claim=fixed tree=deadbee0 stamped=2026-09-17 fix=taken open=0`"
    set files {} ; set base {}
    foreach {n v} [list 9121 "**STAMP** $q16b" 9122 "STAMP $q16b" 9123 "**Stamp** $q16b" 9124 "**STAMP -** $q16b" \
                        9125 "**STAMP;** $q16b" 9126 "**STAMP.** $q16b" 9127 "the stamp we meant was $q16b, never landed" \
                        9129 "the batch reads `v1 v2 v3` newest-first; `v1 = 8.333333e-01` is volts; see **STAMP:** `v1 ...` in the spec"] {
        lappend files $n-x.md "# $n - x\n\n$v\n\nprose."
        append base "$n-x.md\n"
    }
    lappend files 9128-x.md "# 9128 - x\n\n$RB_ST\n**STAMP** $q16b\n\nprose."
    lassign [mkcorpus q16 $files $base] id bf
    set r [with_plain_root $RB_ROOT {
        problems_per_file $id $bf "a line carrying a stamp's body" \
            {9121 {} 9122 {} 9123 {} 9124 {} 9125 {} 9126 {} 9127 {} 9128 {} 9129 {}}
    }]
    set r
} {1 1 1 1 1 1 1 1 0}

## ⚠ D19 -- GRANDFATHERED BY EXACT FILE NAME, AND A NAME THAT MISSES THE PATTERN
## IS NAMED.  The baseline held NUMBERS, so a NEW unstamped file under a
## grandfathered number inherited the exemption: `1349-a-second-defect-under-a-
## colliding-number.md` passed `ok (0 problems)` on every arm, and CLAUDE.md
## records 1349-1353 as real cross-clone collisions (MEASURED by S1-fix6's
## refuter, red-first by S1-fix7).  And a name the glob never listed was never
## read: `1601_x.md`, `1601.md`, `1601-x.MD`, `1601 x.md`, `160-x.md` each
## passed.  Here, one gate: the original 1349 (grandfathered by its name) is
## clean, the second 1349 is a NEW file, each misnamed file is named once, and
## the known NEGATIVES -- an attachment `1601-attempt-1.patch` and NUMBERING.md
## -- are not.  Then two baselines the reader must REFUSE rather than half-read:
## one line a bare number (the old format), one line neither a comment nor a name.
check_needs "Q17 RED: grandfathering is by EXACT FILE NAME -- a new unstamped file under a grandfathered number is RED -- names that look like issue files and miss NNNN-<slug>.md are named, and a baseline line that is a bare number or not a name refuses the baseline" {
    lassign [mkcorpus q17 [list \
        1349-original.md "# 1349 - the original\n\nStatus: OPEN." \
        1349-a-second-defect-under-a-colliding-number.md "# 1349 - a second defect\n\nStatus: OPEN." \
        1601_x.md "# 1601\n" 1601.md "# 1601\n" 1601-x.MD "# 1601\n" "1601 x.md" "# 1601\n" 160-x.md "# 160\n" \
        1601-attempt-1.patch "diff\n" NUMBERING.md "# numbering\n"] "1349-original.md"] id bf
    set r [with_plain_root $RB_ROOT {
        set p [with_corpus $id $bf {istamp::gate}]
        set out {}
        foreach needle {"1349 (1349-original.md)" "1349 (1349-a-second-defect-under-a-colliding-number.md): a NEW issue file"} {
            set c 0 ; foreach x $p { if {[string first $needle $x] == 0} { incr c } } ; lappend out $c
        }
        set c 0 ; foreach x $p { if {[string match "*: looks like an issue file but is not named*" $x]} { incr c } } ; lappend out $c
        foreach needle {1601-attempt-1.patch NUMBERING.md} {
            set c 0 ; foreach x $p { if {[string first $needle $x] >= 0} { incr c } } ; lappend out $c
        }
        lappend out [llength $p]
        set fh [open $bf w] ; puts $fh "# a comment\n1349-original.md\n1349" ; close $fh
        lappend out [string match "BASELINE UNUSABLE: * bare issue number on line 3 *" [lindex [with_corpus $id $bf {istamp::gate}] 0]]
        set fh [open $bf w] ; puts $fh "1349-original.md\n1349 original" ; close $fh
        lappend out [string match "BASELINE UNUSABLE: * not an issue file's name on line 2 *" [lindex [with_corpus $id $bf {istamp::gate}] 0]]
        set out
    }]
    set r
} {0 1 5 0 0 6 1 1}

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

set D9_PROBLEMS [istamp::gate]
set D9_SKIPS    $istamp::last_skips
set D9_VERIFIED $istamp::last_verified
check "D9 the gate is GREEN on the real corpus as it stands today" \
    [llength $D9_PROBLEMS] \
    0
## A red D9 says WHAT is wrong, not only how many: in a download put under git
## and committed -- red by design (D14) -- the checker's own words name that
## shape and its cure, and a stranger reading this log should see them here.
## Indented, never at column 0, and none of the checker's problems ends in a
## word T1 counts.
if {[llength $D9_PROBLEMS]} {
    foreach p [lrange $D9_PROBLEMS 0 2] { puts "      problem: $p" }
    if {[llength $D9_PROBLEMS] > 3} {
        puts "      ...and [expr {[llength $D9_PROBLEMS] - 3}] more: tclsh tests/headless/issue_stamp.tcl gate lists them all"
    }
}

## ⚠ D9 ALONE CANNOT TELL "VERIFIED" FROM "NOT ASKED".  Where history is absent
## the gate still runs every rule that does not need it -- the header window, the
## grammar, the baseline, assert= and the mirror check -- and reports what it
## could not verify in last_skips instead of as problems.  So D9 stays a real
## check in every shape, and D9h below carries the part that needs history.
##
## The census of the real corpus, read by THIS suite: every well-formed stamp,
## as {num tree stamped}.  A file that cannot be read is named, not fatal -- the
## gate reports it as a problem, so D9 is the row that goes red on it.
## Nothing listed or read when the corpus directory leads out (see B1): D9 is
## red on the gate's own CORPUS problem, and H9 names it below.
lassign [istamp_d9_census] D9_STAMPS D9_UNREADABLE CORPUS_DP
if {$CORPUS_DP ne ""} { puts "      the corpus was NOT READ: $CORPUS_DP" }
if {[llength $D9_UNREADABLE]} {
    puts "      [llength $D9_UNREADABLE] issue file(s) could not be READ: $D9_UNREADABLE"
}
set D9_NSTAMPED [llength $D9_STAMPS]
## The distinct revisions the real corpus names -- git is asked about each ONCE.
set D9_REVS {}
foreach st $D9_STAMPS { lappend D9_REVS [lindex $st 1] }
set D9_REVS [lsort -unique $D9_REVS]
## Does each resolve AND lie in HEAD's history, asked of git directly and not
## through the gate?  `ok`, `unresolved` or `not in HEAD's history`.  Only where
## git may be asked and a history is complete enough for the answer to mean
## something: never in `none`/`unborn` (git would answer from a repository
## above), never in a shallow clone (H9 and D9h do not run there).
## Caught: this runs at the top level, and a census that threw would take every
## row after it down with it -- H9 names the error instead.
set D9_RESOLVES {}
foreach rv $D9_REVS {
    if {[catch {
            if {$HSTATE ni {full unreadable}} {
                set r "not asked"
            } elseif {![istamp::rev_exists $rv]} {
                set r unresolved
            } elseif {[istamp::rev_is_ancestor $rv] != 1} {
                set r "not in HEAD's history"
            } else {
                set r ok
            }
        } err]} {
        set r "CENSUS DIED: [lindex [split $err \n] 0]"
    }
    dict set D9_RESOLVES $rv $r
}
if {[llength $D9_SKIPS]} {
    puts "      [llength $D9_SKIPS] stamped revision(s) in the real corpus NOT VERIFIED ($HSTATE):"
    foreach s $D9_SKIPS { puts "        not verified: $s" }
}
## ⚠ IN A HISTORY WITH COMMITS THE GATE'S SKIP SET IS EMPTY -- ASSERTED HERE,
## NOT PROMISED IN A COMMENT.  S1-fix2's header promised that its date rule's
## skip set was "empty in every ordinary clone of this project", and nothing
## held it: its refuter planted a backdated bogus stamp in an ordinary full
## clone, the gate skipped it by name, and every row stayed green.  The third
## column is that skip set, required EMPTY.  Non-vacuous: at least one stamp
## verified, and every stamp verified.
## ⚠ ONE KIND OF SKIP IS NOT AN EXEMPTION, AND IS LEFT OUT OF THAT COLUMN: a
## partial clone's quote= whose CONTENT was never fetched (D19; quote_gap).  Its
## revision was verified; the checker never fetches, so the blob is simply not
## there to compare, and it is printed above as `not verified:` by name.  Held
## in a full clone it would turn a stranger's blob:none clone RED the day the
## corpus gains a quote of old content -- today it holds none (MEASURED).
check_needs "D9h every stamped revision in the real corpus is VERIFIED, and the gate skipped NOTHING -- a history with commits has no exemptions" {
    list [expr {$D9_VERIFIED > 0}] [expr {$D9_VERIFIED == $D9_NSTAMPED}] \
         [lsearch -all -inline -not -glob $D9_SKIPS {*(partial clone: *}]
} {1 1 {}}

check "D9b the self-test is a precondition of any verdict, not a separate command" \
    [llength [istamp::selftest]] \
    0

## ---------------------------------------------------------------------------
## H -- THE SKIP PATH IS TAKEN ONLY WHEN HISTORY IS TRULY ABSENT
## ---------------------------------------------------------------------------
##
## ⚠ A SKIP IS THE EASIEST VACUOUS GREEN THERE IS: it arrives with a reason
## attached, so it reads as care.  A probe that misread a full clone as shallow
## would quietly stop G4 and D9h from ever running again, and every run after
## that would be green.  So the skip path is held to KNOWN ANSWERS: repositories
## built here, one per state and one per way of being broken, each with a known
## history and PINNED dates, and the gate's verdict on each asserted exactly --
## including that a full history still REFUSES a bogus revision (H2), that a
## .git git cannot read skips NOTHING (H5), and that no date and no shape of
## history -- backdated, re-initialised, grafted, orphan-squashed, re-dated --
## earns an unresolved revision a skip (H8, H11, H13).  These rows need only the
## git program, not this tree's history, so they run in the shallow clone and in
## the export too: they are what proves there that G4's refusal still works.
##
## Every verdict below is {problems skipped verified}: how many problems the
## gate reported, how many revision questions it could not ask, and how many
## tree= revisions it verified.

## ⚠ THE FIXTURES ARE BUILT HERMETICALLY -- AND THIS COMMENT CLAIMS ONLY WHAT IS
## SEALED, BECAUSE THE LAST ONE DID NOT.  This is the first T1 suite that makes
## git WRITES, and S1 shipped it inheriting the caller's environment, with a
## comment claiming "every knob ... is pinned".  S1's refuters MEASURED what
## that cost:
##   * with GIT_DIR exported to another repository, the fixture's `git init` /
##     `add` / `commit` went THERE: commits `c1` and `c2` landed on the checked-
##     out branch of the repository GIT_DIR named;
##   * run from a pre-commit hook, which git hands an ABSOLUTE GIT_INDEX_FILE
##     (measured, git 2.53: `<repo>/.git/index.lock` for `commit -a`), the
##     fixture's `git add a.txt` wrote into the USER's pending commit, which then
##     aborted with `invalid object ... for 'a.txt'`;
##   * `protocol.file.allow=never` in the tester's config refused the fixture's
##     file:// clone, and H1-H5 went red on `transport 'file' not allowed`.
## S1-fix then sealed the environment and wrote "NOTHING ABOUT THE CALLER'S git
## ENVIRONMENT MAY CHANGE WHAT THEY ARE" -- and ITS refuter measured three
## things that still did, every one a false red of seven rows: the ignore and
## attributes files git reads from ~/.config/git by DEFAULT PATH (they are not
## config, so GIT_CONFIG_GLOBAL=/dev/null never touched them), and
## GIT_QUARANTINE_PATH, which a server's pre-receive hook sets.
##
## What IS sealed, then, each one measured red before and green after:
##   * the variables below, removed for every fixture step -- the build AND the
##     checker's reads of the fixtures -- and put back after: the repository-
##     locating ones, the config ones, the author/committer overrides, the
##     object/ref format and template directory, git's ownership-test knob,
##     GIT_QUARANTINE_PATH and GIT_ALLOW_PROTOCOL (an env override of the
##     protocol pin below).  The build script ALSO unsets whatever `git
##     rev-parse --local-env-vars` names, so a variable a future git adds to
##     that list is covered too (row H0 checks the list against it);
##   * system and global config OFF (GIT_CONFIG_NOSYSTEM, GIT_CONFIG_GLOBAL);
##   * the default-path ignore and attributes files OFF, by config on every
##     fixture command (core.excludesFile, core.attributesFile = /dev/null), and
##     every `git add` is `add -f` besides; GIT_ATTR_NOSYSTEM is set too, for
##     the system attributes file, which a non-root run cannot plant to prove it;
##   * hooks, signing, the default branch and the file:// transport pinned on
##     every fixture command, and every commit's dates pinned (H2-H12 read them).
## ⚠ AND THE BUILD RUNS WITH A HOSTILE ENVIRONMENT PLANTED ON PURPOSE, every run:
## an XDG_CONFIG_HOME whose git/ignore ignores everything and whose
## git/attributes re-encodes everything, and a GIT_QUARANTINE_PATH.  If any of
## the ignore, attributes or quarantine seal goes, the build fails and every
## fixture row (H1-H5, H8, H10-H12) goes red with FIXTURES NOT BUILT -- in THIS
## run, on this box, not on a tester's.  (The ignore seal has two layers,
## core.excludesFile and `add -f`; either alone holds -- MEASURED -- and the
## plant reddens only when both go.)  The variable list is H0's to hold.  Not
## sealed, and not claimed: GIT_EXEC_PATH and the like, which change which git
## runs at all.
##
## Command-scope config is removed with the rest, and that is deliberate: the
## drivers export GIT_CONFIG_COUNT=1 / safe.directory=<this tree> into every
## suite (outsider-fixes DECISIONS D7), which is about THIS TREE, never about
## repositories this suite creates and therefore owns.
## GIT_TEST_ASSUME_DIFFERENT_OWNER is git's own simulation of a checkout another
## uid owns; the fixtures are never that, so it is removed too, and the rows
## below keep measuring the checker rather than the simulation.
set FIXTURE_ENV_UNSET {
    GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
    GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_IMPLICIT_WORK_TREE
    GIT_GRAFT_FILE GIT_NO_REPLACE_OBJECTS GIT_REPLACE_REF_BASE GIT_PREFIX
    GIT_SHALLOW_FILE GIT_NAMESPACE
    GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_CONFIG_SYSTEM
    GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_AUTHOR_DATE
    GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_COMMITTER_DATE
    GIT_DEFAULT_HASH GIT_DEFAULT_REF_FORMAT GIT_TEMPLATE_DIR
    GIT_TEST_ASSUME_DIFFERENT_OWNER
    GIT_QUARANTINE_PATH GIT_ALLOW_PROTOCOL GIT_ATTR_SOURCE
    GIT_NO_LAZY_FETCH
}
set FIXTURE_ENV_SET {GIT_CONFIG_NOSYSTEM 1 GIT_CONFIG_GLOBAL /dev/null GIT_ATTR_NOSYSTEM 1}

## Run $body (in the caller's frame) under the fixture environment above.
## Everything is put back exactly as it was, whatever $body does.
proc with_fixture_env {body} {
    set names [concat $::FIXTURE_ENV_UNSET [dict keys $::FIXTURE_ENV_SET]]
    set saved {}
    foreach v $names {
        if {[info exists ::env($v)]} { lappend saved $v $::env($v) }
    }
    foreach v $::FIXTURE_ENV_UNSET {
        if {[info exists ::env($v)]} { unset ::env($v) }
    }
    foreach {v val} $::FIXTURE_ENV_SET { set ::env($v) $val }
    set rc [catch {uplevel 1 $body} res opt]
    foreach v $names {
        if {[info exists ::env($v)]} { unset ::env($v) }
    }
    foreach {v val} $saved { set ::env($v) $val }
    if {$rc} { return -options $opt $res }
    return $res
}

## A file:// URL for an absolute path, PERCENT-ENCODED.  git decodes %XX in a
## file:// URL, so a parent directory called `pct%41dir` reached git as
## `pctAdir` and the fixture clone failed: `does not appear to be a git
## repository` (MEASURED by S1-fix's refuter; S1's bytes had it too).  Every byte
## outside the unreserved set is encoded -- `%` itself, a space, `#`, `?`, `:`,
## brackets, `$`, and each byte of a UTF-8 name -- each MEASURED to clone.
## ⚠ THE BYTES ARE THE PATH'S NATIVE BYTES, taken through the SYSTEM encoding,
## which is what decoded the path in the first place -- not through utf-8.  It
## said `convertto utf-8`, and under LANG=C (Tcl's system encoding iso8859-1)
## a checkout under a UTF-8 directory `café/` was decoded as two characters per
## accented letter and re-encoded as four bytes: git answered `'…/cafÃ©/…' does
## not appear to be a git repository` and 19 rows (18 H rows and Q7) went red
## for a stranger whose tree was fine (MEASURED by S1-fix6; identical on
## S1-fix5's bytes).
proc istamp_file_url {path} {
    set out ""
    foreach b [split [encoding convertto [encoding system] [file normalize $path]] ""] {
        if {[regexp {^[A-Za-z0-9/._~-]$} $b]} {
            append out $b
        } else {
            binary scan $b cu c
            append out [format %%%02X $c]
        }
    }
    return file://$out
}

## The fixture repositories, with known commits and PINNED dates.
##   full        c1 (2026-01-01), c2 = HEAD (2026-01-02)
##   shallow     a --depth 1 clone of full: c2 only
##   none        a plain subdirectory OF THE FULL ONE -- the shape of an export
##               unpacked inside another repository -- so if the checker ever
##               asked git there, git WOULD answer, from the full fixture's
##               history, and c1 would resolve.  That is what makes H4's
##               "skipped" a measurement, not an assumption
##   unreadable  an empty .git
##   unborn      `git init`, nothing more
##   staged      `git init` + `git add`: blobs in the store, still no commit
##   orphan      full, with an orphan branch checked out: HEAD names nothing,
##               but the refs and the history are there.  It must be
##               `unreadable`, never `unborn` -- the fail-closed half of unborn
##   reinit      an unrelated history, f1, committed 2026-09-20 -- after the
##               2026-09-18 stamps of the hrow corpora: a download put back
##               under git
##   corrupt     full, with c1's object replaced by garbage: HEAD reads fine,
##               the ancestry walk does not
##   noshallow   shallow, with git's `shallow` file deleted: git no longer
##               knows it is shallow, and c2's parent is simply missing -- the
##               clone S1-fix's refuter caught reading as a skip
##   graft       full plus c3 (authored 2026-09-20), then `git replace --graft
##               HEAD`: honouring the replace ref, HEAD is a root commit
##               authored after every stamp -- S1-fix2's refuter's graft
##   orphanc     full with an orphan branch COMMITTED (sq, 2026-09-20) and
##               checked out: HEAD's ancestry is sq alone, while c1 and c2 are
##               still in the store and on `main` -- the refuter's orphan squash
##   rootdate    full's history rewritten, only the root's AUTHOR date moved to
##               2026-09-20 (x1, then x2 authored 2026-01-02): every SHA new,
##               every other date kept -- the refuter's root-date rewrite
## and, for D15 (each one a shape S1-fix3's refuter measured failing open):
##   offpath     main (c1, c2) cloned whole, then ANOTHER branch (s1, on c1)
##               fetched with --depth 1: git calls the repository shallow and
##               its shallow file names s1, while HEAD's history is complete --
##               the refuter's fetchd / selfdepth / ciflow
##   eshallow    full with an EMPTY `shallow` file: flagged, nothing cut
##   reachroot   a --depth 2 clone of full: a depth that reaches the true root,
##               which git LISTS in the shallow file (MEASURED) and which cuts
##               nothing -- why "listed in the shallow file" is not the test
##   dangling    .git is a symbolic link to nowhere -- `file exists` said none
##   gitfile     .git is a gitfile naming a directory that does not exist
##   grafts      full plus c3, with a LEGACY `.git/info/grafts` making c3 a
##               root: the stored history (and a stranger's clone) says c1
##   amend       full plus `commit --allow-empty` (am) and `reset --soft HEAD~1`:
##               am is in the store and in NO ref's history -- the refuter's
##               amended-away stamp
##   shamend     the same on the shallow clone (am2 on c2), where "not an
##               ancestor" cannot be told from "beyond the boundary"
## and, for D16 (S1-fix4's refuter measured both failing open):
##   fdself      full cloned whole, then `fetch --depth 1 origin main` with
##               nothing new: the shallow file names c2 -- HEAD ITSELF -- and
##               every commit is still in the store
##   fdanc       ancsrc (full + a3, branch anc on c2) cloned whole, then `fetch
##               --depth 1 origin anc`: the shallow file names c2, an ANCESTOR
##               of HEAD with a parent, and again nothing is missing
## and, for D19 (S1-fix6's refuter measured a partial clone fetching):
##   partial     psrc (full + p3, which rewrites a.txt, served with
##               uploadpack.allowFilter) cloned --filter=blob:none: c1:a.txt's
##               blob -- bl below -- is NOT in it, while its origin, which WOULD
##               serve it, still exists; so a checker that ever fetches is
##               caught by the blob turning up
##   nopromise   full with that same blob's object DELETED: a store missing
##               content it should hold, and NOT a partial clone -- where a
##               missing blob is a defect, never a gap to excuse
## (bl and tr, printed with the revisions, are full's HEAD:a.txt blob and HEAD's
## tree: objects that are in every clone, shallow included, and are not commits.)
## orphan, corrupt and noshallow are the fail-closed rows of the probe: each is
## broken in a way that a probe taking ANY failure as "history absent" would
## skip on -- and dangling and gitfile now join them.  reinit, graft, orphanc,
## rootdate, offpath, eshallow, reachroot and amend are the fail-closed rows of
## the gate: each is a readable history in which an earlier round's exemption
## (`foreign`, the date rule, the repository-wide shallow flag, "it is in the
## store") skipped or passed a stamp that no other clone could verify.
##
## ONE exec, not a dozen: every exec here goes through `timeout` (the rule at
## the head of issue_stamp.tcl), and `timeout` alone costs ~100 ms a call on
## this box.  It holds with_fixture_env ITSELF, so there is no way to call it
## bare, and it plants the hostile environment described above AROUND that, so
## the seal is exercised by every run that builds the fixtures.
proc istamp_hist_fixtures {} {
    set root [istamp_own [file join $::ISTAMP_SCRATCH_ROOT istamp_[pid]_hist]]
    file delete -force $root
    file mkdir $root
    set plant [file join $root .hostile]
    file mkdir [file join $plant git]
    set fh [open [file join $plant git ignore] w]
    puts $fh "*"
    close $fh
    set fh [open [file join $plant git attributes] w]
    puts $fh "* working-tree-encoding=UTF-16"
    close $fh
    set script {
        set -e
        cd "$1"
        unset $(git rev-parse --local-env-vars 2>/dev/null) 2>/dev/null || :
        g() { git -c user.name=istamp -c user.email=istamp@invalid \
                  -c commit.gpgsign=false -c core.hooksPath=/dev/null \
                  -c init.defaultBranch=main -c protocol.file.allow=always \
                  -c core.excludesFile=/dev/null -c core.attributesFile=/dev/null \
                  "$@"; }
        when() { GIT_AUTHOR_DATE="$1"; GIT_COMMITTER_DATE="$2"
                 export GIT_AUTHOR_DATE GIT_COMMITTER_DATE; }
        mkdir full && cd full
        g init -q
        echo one > a.txt && g add -f a.txt
        when "@1767268800 +0000" "@1767268800 +0000" && g commit -q -m c1
        c1=$(g rev-parse HEAD)
        echo two > b.txt && g add -f b.txt
        when "@1767355200 +0000" "@1767355200 +0000" && g commit -q -m c2
        c2=$(g rev-parse HEAD)
        cd ..
        g clone -q --depth 1 "$2" shallow
        mkdir full/sub
        mkdir -p broken/.git
        mkdir unborn && g -C unborn init -q
        mkdir staged && g -C staged init -q
        echo s > staged/s.txt && g -C staged add -f s.txt
        cp -R full orphan && g -C orphan checkout -q --orphan fresh
        mkdir reinit && cd reinit
        g init -q
        echo other > z.txt && g add -f z.txt
        when "@1789905600 +0000" "@1789905600 +0000" && g commit -q -m f1
        f1=$(g rev-parse HEAD)
        cd ..
        cp -R full corrupt
        o="corrupt/.git/objects/$(printf %s "$c1" | cut -c1-2)/$(printf %s "$c1" | cut -c3-)"
        chmod u+w "$o"
        printf 'not a git object' > "$o"
        cp -R shallow noshallow && rm noshallow/.git/shallow
        cp -R full graft && cd graft
        echo three > c.txt && g add -f c.txt
        when "@1789905600 +0000" "@1789905600 +0000" && g commit -q -m c3
        c3=$(g rev-parse HEAD)
        g replace --graft HEAD
        cd ..
        cp -R orphan orphanc
        when "@1789905600 +0000" "@1789905600 +0000" && g -C orphanc commit -q -m sq
        sq=$(g -C orphanc rev-parse HEAD)
        mkdir rootdate && cd rootdate
        g init -q
        echo one > a.txt && g add -f a.txt
        when "@1789905600 +0000" "@1789905600 +0000" && g commit -q -m c1
        x1=$(g rev-parse HEAD)
        echo two > b.txt && g add -f b.txt
        when "@1767355200 +0000" "@1789905600 +0000" && g commit -q -m c2
        cd ..
        cp -R full sidesrc
        g -C sidesrc checkout -q -b side "$c1"
        echo side > sidesrc/s.txt && g -C sidesrc add -f s.txt
        when "@1767441600 +0000" "@1767441600 +0000" && g -C sidesrc commit -q -m s1
        s1=$(g -C sidesrc rev-parse HEAD)
        g -C sidesrc checkout -q main
        g clone -q --single-branch -b main "$3" offpath
        g -C offpath fetch -q --depth 1 origin side
        cp -R full eshallow && : > eshallow/.git/shallow
        g clone -q --depth 2 "$2" reachroot
        mkdir dangling && ln -s "$1/no-such-gitdir" dangling/.git
        mkdir gitfile && printf 'gitdir: %s\n' "$1/no-such-gitdir" > gitfile/.git
        cp -R full grafts && cd grafts
        echo three > c.txt && g add -f c.txt
        when "@1789905600 +0000" "@1789905600 +0000" && g commit -q -m c3
        mkdir -p .git/info && g rev-parse HEAD > .git/info/grafts
        cd ..
        cp -R full amend
        when "@1767441600 +0000" "@1767441600 +0000" && g -C amend commit -q --allow-empty -m am
        am=$(g -C amend rev-parse HEAD)
        g -C amend reset -q --soft HEAD~1
        cp -R shallow shamend
        when "@1767441600 +0000" "@1767441600 +0000" && g -C shamend commit -q --allow-empty -m am2
        am2=$(g -C shamend rev-parse HEAD)
        g -C shamend reset -q --soft HEAD~1
        g clone -q "$2" fdself
        g -C fdself fetch -q --depth 1 origin main
        cp -R full ancsrc
        echo four > ancsrc/d.txt && g -C ancsrc add -f d.txt
        when "@1767441600 +0000" "@1767441600 +0000" && g -C ancsrc commit -q -m a3
        a3=$(g -C ancsrc rev-parse HEAD)
        g -C ancsrc branch anc "$c2"
        g clone -q --single-branch -b main "$4" fdanc
        g -C fdanc fetch -q --depth 1 origin anc
        cp -R full psrc
        echo three > psrc/a.txt && g -C psrc add -f a.txt
        when "@1767441600 +0000" "@1767441600 +0000" && g -C psrc commit -q -m p3
        g -C psrc config uploadpack.allowFilter true
        g clone -q --filter=blob:none "$5" partial
        bl=$(g -C full rev-parse HEAD:a.txt)
        tr=$(g -C full rev-parse 'HEAD^{tree}')
        cp -R full nopromise
        rm -f "nopromise/.git/objects/$(printf %s "$bl" | cut -c1-2)/$(printf %s "$bl" | cut -c3-)"
        echo "ISTAMP_REVS $c1 $c2 $f1 $c3 $sq $x1 $s1 $am $am2 $a3 $bl $tr"
    }
    set url  [istamp_file_url [file join $root full]]
    set surl [istamp_file_url [file join $root sidesrc]]
    set aurl [istamp_file_url [file join $root ancsrc]]
    set purl [istamp_file_url [file join $root psrc]]
    ## The hostile plant goes in AROUND with_fixture_env, never inside it: the
    ## seal is what must defeat it.  Put back exactly as it was, on every path.
    set hostile [list XDG_CONFIG_HOME $plant GIT_QUARANTINE_PATH [file join $plant quarantine]]
    set hsaved {}
    foreach {v val} $hostile {
        if {[info exists ::env($v)]} { lappend hsaved $v $::env($v) }
        set ::env($v) $val
    }
    set rc [catch {with_fixture_env {exec timeout 60 sh -c $script sh $root $url $surl $aurl $purl 2>@1}} out opt]
    foreach {v val} $hostile { unset ::env($v) }
    foreach {v val} $hsaved { set ::env($v) $val }
    if {$rc} { return -options $opt $out }
    set h {([0-9a-f]{40,64})}
    if {![regexp "ISTAMP_REVS $h $h $h $h $h $h $h $h $h $h $h $h" $out -> c1 c2 f1 c3 sq x1 s1 am am2 a3 bl tr]} {
        error "the fixture script printed no revisions: [string trim $out]"
    }
    set fx [dict create c1 $c1 c2 $c2 f1 $f1 c3 $c3 sq $sq x1 $x1 s1 $s1 am $am am2 $am2 a3 $a3 bl $bl tr $tr]
    foreach {st sub} {full full shallow shallow none {full sub} unreadable broken
                      unborn unborn staged staged orphan orphan reinit reinit
                      corrupt corrupt noshallow noshallow graft graft
                      orphanc orphanc rootdate rootdate offpath offpath
                      eshallow eshallow reachroot reachroot dangling dangling
                      gitfile gitfile grafts grafts amend amend shamend shamend
                      fdself fdself fdanc fdanc partial partial nopromise nopromise} {
        dict set fx $st [file join $root {*}$sub]
    }
    return $fx
}

## Point the checker at repository $dir for the length of $body, through init's
## own <rootdir> arm -- the arm that used to ignore its argument -- and put back
## exactly what was there before.  Restored from the saved values rather than by
## a second init(), which would re-probe: two more execs for nothing.
proc with_repo {dir body} {
    set saved [list $istamp::repo $istamp::issues_dir $istamp::baseline $istamp::history]
    istamp::init $dir
    set rc [catch {uplevel 1 $body} res opt]
    lassign $saved istamp::repo istamp::issues_dir istamp::baseline istamp::history
    if {$rc} { return -options $opt $res }
    return $res
}

## The gate's verdict on a one-file corpus, in whatever repository the checker
## is currently pointed at (hrow points it, once per state).
proc hverdict {stamp {tail ""}} {
    lassign [mkcorpus h[incr ::HN] [list 9999-x.md "# 9999 - x

**STAMP:** `$stamp`$tail"] ""] id bf
    set p [with_corpus $id $bf {istamp::gate}]
    list [llength $p] [llength $istamp::last_skips] $istamp::last_verified
}

## ONE gate over several one-stamp files, in whatever repository the checker is
## pointed at: per file {problems skipped}, in order, then the corpus's verified
## count; the problems themselves are left in ::HC_LAST for a row that reads the
## words.  hverdict runs one gate per stamp, and every gate asks git again --
## `timeout` alone costs ~100 ms a call here (uutils 0.8.0, MEASURED) -- so a row
## that only needs per-file counts asks them all in one run: within a run, each
## revision is asked once (rev_cache).
proc hcorpus {files} {
    set pairs {}
    set n 9000
    foreach f $files {
        lassign $f stamp tail
        incr n
        lappend pairs $n-x.md "# $n - x\n\n**STAMP:** `$stamp`$tail"
    }
    lassign [mkcorpus h[incr ::HN] $pairs ""] id bf
    set ::HC_LAST [with_corpus $id $bf {istamp::gate}]
    set out {}
    for {set i 9001} {$i <= $n} {incr i} {
        set np 0 ; set ns 0
        foreach x $::HC_LAST          { if {[string match "$i:*" $x]} { incr np } }
        foreach x $istamp::last_skips { if {[string match "$i:*" $x]} { incr ns } }
        lappend out [list $np $ns]
    }
    lappend out $istamp::last_verified
    return $out
}

## Seven known corpora, the same seven in every state, every one STAMPED
## 2026-09-18 -- a date that decides nothing, since no rule reads it (D14):
##   A  tree= an OLD commit (c1), beyond a --depth 1 clone
##   B  tree= a revision that exists nowhere
##   C  tree= HEAD (c2), present even in a shallow clone
##   D  a malformed stamp -- a defect that needs NO history to see
##   E  tree=c2, plus a quote= of c1 that HOLDS
##   F  tree=c2, plus a quote= of c1 that has ROTTED
##   G  tree= the REINIT repository's commit (f1) -- verified only there, which
##      is what tells a history that is asked apart from `none` (never ask)
## Always run under with_fixture_env.
proc hrow {state} {
    if {$::HF_ERR ne ""} { return "FIXTURES NOT BUILT: $::HF_ERR" }
    set dir [dict get $::HF $state]
    set c1  [dict get $::HF c1]
    set c2  [dict get $::HF c2]
    set f1  [dict get $::HF f1]
    set bogus [string repeat deadbeef 5]
    with_fixture_env {
        with_repo $dir {
            set out {}
            lappend out [hverdict "v1 claim=open tree=$c1 stamped=2026-09-18 fix=none open=0"]
            lappend out [hverdict "v1 claim=open tree=$bogus stamped=2026-09-18 fix=none open=0"]
            lappend out [hverdict "v1 claim=open tree=$c2 stamped=2026-09-18 fix=none open=0"]
            lappend out [hverdict "v1 claim=fixed tree=$c1 stamped=2026-09-18 fix=superseded open=0"]
            lappend out [hverdict "v1 claim=open tree=$c2 stamped=2026-09-18 fix=none open=0" \
                             "\n\n```txt quote=$c1 path=a.txt\none\n```"]
            lappend out [hverdict "v1 claim=open tree=$c2 stamped=2026-09-18 fix=none open=0" \
                             "\n\n```txt quote=$c1 path=a.txt\ntwo\n```"]
            lappend out [hverdict "v1 claim=open tree=$f1 stamped=2026-09-18 fix=none open=0"]
        }
    }
    return $out
}

## The on-disk evidence for a tree's history state, read WITHOUT asking git:
## no .git -> none; a .git with no HEAD file -> unreadable; git's own `shallow`
## file present -> shallow; HEAD naming a branch that has neither a loose ref
## nor a packed one -> unborn; otherwise full.  A worktree's .git is a FILE
## naming its own git dir -- where ITS HEAD lives -- whose `commondir` holds the
## shared one, where the refs and a shallow worktree's `shallow` file live.
## Nothing on disk says whether a history is COMPLETE, so a corrupt clone reads
## as full here; that is the probe's job, and H1 holds the probe to it.
## ⚠ AND A `shallow` FILE IS NOT, BY ITSELF, A SHALLOW HISTORY (D15, D16): its
## boundary may sit on another branch, and even a boundary AT HEAD -- a no-op
## `fetch --depth 1` of this branch -- may cut nothing the store does not hold.
## This used to read "a shallow file listing HEAD is `shallow`", and that is
## exactly the fdself shape.  Whether the commits beyond a boundary are in the
## store cannot be read from files without parsing packs, so ANY shallow file is
## `shallowrepo`, "git calls it shallow", which H6 accepts as full or shallow --
## the probe is held to the difference by H1 and H19, on fixtures.
## ⚠ lstat, as the probe does: a .git that is a link to nowhere is unreadable.
proc istamp_disk_evidence {root} {
    set g [file join $root .git]
    if {[catch {file lstat $g gst}]} { return none }
    if {![file exists $g]} { return unreadable }
    set wd $g
    set cd $g
    if {[file isfile $g]} {
        if {![regexp {^gitdir:[ \t]*(.+)$} [string trim [istamp::read_file $g]] -> wd]} {
            return unreadable
        }
        if {[file pathtype $wd] eq "relative"} { set wd [file join $root $wd] }
        set cd $wd
        if {[file exists [file join $wd commondir]]} {
            set cd [string trim [istamp::read_file [file join $wd commondir]]]
            if {[file pathtype $cd] eq "relative"} { set cd [file join $wd $cd] }
        }
    }
    if {![file exists [file join $wd HEAD]]} { return unreadable }
    set head [string trim [istamp::read_file [file join $wd HEAD]]]
    ## HEAD's commit as the files name it: a detached HEAD holds it, a branch's
    ## is its loose ref or its packed-refs line.  "" when it cannot be read that
    ## way (a reftable repository, or a branch with no commit yet).
    set hsha ""
    set unborn 0
    if {[regexp {^ref:[ \t]*(\S+)$} $head -> ref]} {
        if {[file isdirectory [file join $cd reftable]]} {
            ## not readable as files: neither unborn nor a known commit
        } elseif {[file exists [file join $cd $ref]]} {
            set hsha [string trim [istamp::read_file [file join $cd $ref]]]
        } else {
            set unborn 1
            if {[file exists [file join $cd packed-refs]]} {
                foreach ln [split [istamp::read_file [file join $cd packed-refs]] \n] {
                    set ln [split [string trim $ln]]
                    if {[lindex $ln end] eq $ref} { set hsha [lindex $ln 0] ; set unborn 0 ; break }
                }
            }
        }
    } else {
        set hsha $head
    }
    set sf [file join $cd shallow]
    if {[file exists $sf]} { return shallowrepo }
    if {$unborn} { return unborn }
    return full
}

## What history verdicts the disk evidence admits (H6).
proc istamp_disk_admits {disk} {
    if {$disk eq "shallowrepo"} { return {full shallow} }
    return [list $disk]
}

## ⚠ H0 RUNS BEFORE ANY FIXTURE IS BUILT, because the damage it guards against
## happens AT build time, in somebody else's repository.  It is a known-answer
## test of with_fixture_env: EVERY variable git itself calls repository-local
## (`git rev-parse --local-env-vars`) must be on the list, a sentinel planted in
## every listed variable must be GONE inside and BACK after, and the system and
## global config and the system attributes file must be off inside.  A list that
## loses GIT_INDEX_FILE, or a git that grows a new repository-local variable, is
## red here -- before the build, not after a user's commit has aborted.
set H0_SENTINEL "istamp-h0-sentinel"
check_needs "H0 the fixture environment removes every variable git calls repository-local, and restores them after" {
    set h0_local [lsort [split [string trim [exec timeout 30 git rev-parse --local-env-vars 2>/dev/null]] \n]]
    set h0_missing {}
    foreach v $h0_local { if {$v ni $::FIXTURE_ENV_UNSET} { lappend h0_missing $v } }
    ## The sentinels are removed and the caller's values put back on EVERY
    ## path out: a sentinel left in GIT_CONFIG_COUNT would break every git call
    ## after this row.
    set h0_saved {}
    foreach v $::FIXTURE_ENV_UNSET {
        if {[info exists ::env($v)]} { lappend h0_saved $v $::env($v) }
        set ::env($v) $H0_SENTINEL
    }
    set h0_rc [catch {with_fixture_env {
        set left {}
        foreach v $::FIXTURE_ENV_UNSET { if {[info exists ::env($v)]} { lappend left $v } }
        list $left $::env(GIT_CONFIG_NOSYSTEM) $::env(GIT_CONFIG_GLOBAL) $::env(GIT_ATTR_NOSYSTEM)
    }} h0_inside]
    set h0_back 0
    foreach v $::FIXTURE_ENV_UNSET {
        if {[info exists ::env($v)]} {
            if {$::env($v) eq $H0_SENTINEL} { incr h0_back }
            unset ::env($v)
        }
    }
    foreach {v val} $h0_saved { set ::env($v) $val }
    if {$h0_rc} { set h0_inside "DIED: [lindex [split $h0_inside \n] 0]" }
    list [expr {[llength $h0_local] > 0}] $h0_missing $h0_inside \
         [expr {$h0_back == [llength $::FIXTURE_ENV_UNSET]}]
} {1 {} {{} 1 /dev/null 1} 1}

set ::HN 0
set ::HF {}
set ::HF_ERR ""
if {$HAVE_GIT} {
    if {[catch {istamp_hist_fixtures} ::HF]} {
        set ::HF_ERR [lindex [split $::HF \n] 0]
        set ::HF {}
    }
}

## Nineteen repositories, and for each the probe's verdict and the evidence on
## disk; for the nine full ones, the root commits the probe found, by name.
## ⚠ THE FAIL-CLOSED COLUMNS are orphan, corrupt, noshallow, dangling and
## gitfile.  On disk the first three read `unborn`, `full` and `full`; a probe
## that took ANY failure of the ancestry walk as "no history", or an unborn HEAD
## alone as "no commits", would skip on each of them -- and noshallow is exactly
## the clone S1-fix's refuter caught reading as a skip.  dangling is the .git
## that `file exists` read as absent (S1-fix3's refuter).  All five must be
## `unreadable`.
## ⚠ AND offpath, eshallow AND reachroot MUST BE `full` (D15): git calls each
## repository shallow, and none of them has cut anything from HEAD's history.
## The repository-wide flag read them all as `shallow`, and a bogus stamp
## skipped (H16 holds that part).  The disk admits either (`shallowrepo`).
## ⚠ THE ROOTS ARE THE STORED HISTORY'S, `--no-replace-objects` and the grafts
## file off: graft's and grafts' are c1, not c3.  A walk that honoured a replace
## ref or a grafts line would stop at c3 -- blind to a missing object behind it,
## and blind to the project's first commit in front of it (lacks_upstream, H14).
## ⚠ AND SO MUST fdself AND fdanc (D16): a no-op `fetch --depth 1` of HEAD, or of
## an ancestor, puts a boundary ON HEAD's path while the store still holds every
## commit.  S1-fix4's probe called both `shallow` and skipped a bogus stamp; the
## store decides now, with the shallow file disregarded.  And the disk can no
## longer tell even a --depth 1 clone apart: every shallow file admits both.
check_needs "H1 the probe classifies twenty-one known repositories correctly -- the broken ones unreadable, never a skip; a boundary the store does not need full -- agrees with their disk evidence, and finds the STORED roots" {
    if {$::HF_ERR ne ""} {
        set r "FIXTURES NOT BUILT: $::HF_ERR"
    } else {
        set r [with_fixture_env {
            set probe {} ; set disk {} ; set roots {}
            set names {}
            foreach k {c1 f1 c3 sq x1} { dict set names [dict get $::HF $k] $k }
            foreach st {full shallow none unreadable unborn staged orphan reinit corrupt noshallow graft orphanc rootdate
                        offpath eshallow reachroot dangling gitfile grafts fdself fdanc} {
                set d [dict get $::HF $st]
                set h [istamp::history_probe $d]
                lappend probe [dict get $h state]
                lappend disk  [istamp_disk_evidence $d]
                if {$st in {full reinit graft orphanc rootdate offpath eshallow reachroot grafts fdself fdanc}} {
                    set rn {}
                    if {[dict exists $h roots]} {
                        foreach sha [dict get $h roots] {
                            lappend rn [expr {[dict exists $names $sha] ? [dict get $names $sha] : "?"}]
                        }
                    }
                    lappend roots [join $rn +]
                }
            }
            ## init's <rootdir> arm really does point the checker where it is told.
            set ret [with_repo [dict get $::HF full] {
                list [expr {$istamp::repo eq [file normalize [dict get $::HF full]]}] \
                     [istamp::history_state]
            }]
            list $probe $disk $roots $ret
        }]
    }
    set r
} {{full shallow none unreadable unborn unborn unreadable full unreadable unreadable full full full full full full unreadable unreadable full full full} {full shallowrepo none unreadable unborn unborn unborn full full full full full full shallowrepo shallowrepo shallowrepo unreadable unreadable full shallowrepo shallowrepo} {c1 f1 c1 sq x1 c1 c1 c1 c1 c1 c1} {1 full}}

check_needs "H2 a FULL history skips NOTHING: an old revision is verified, a bogus one and a rotted quote are REFUSED" {
    hrow full
} {{0 0 1} {1 0 0} {0 0 1} {1 0 0} {0 0 1} {1 0 1} {1 0 0}}

## The honest limit, stated as a measurement: B and F go unrefused here, because
## a shallow clone cannot tell "exists nowhere" from "exists beyond my depth".
## They are NAMED as skipped, never passed -- and HEAD (C, and E/F's tree=) is
## still verified, D is still refused.  Only what is genuinely missing skips.
check_needs "H3 a SHALLOW clone skips only what is genuinely missing: HEAD is still verified, a malformed stamp still refused" {
    hrow shallow
} {{0 1 0} {0 1 0} {0 0 1} {1 0 0} {0 1 1} {0 1 1} {0 1 0}}

## A is the sharp one: this directory sits inside the full fixture, so asking
## git would have VERIFIED c1.  {0 1 0} means git was not asked.
check_needs "H4 with NO repository of its own git is never asked -- a repository above cannot answer for it" {
    hrow none
} {{0 1 0} {0 1 0} {0 1 0} {1 0 0} {0 2 0} {0 2 0} {0 1 0}}

## ⚠ THE FAIL-CLOSED ROW.  A .git git cannot read is not evidence that history
## is absent; it is a broken checkout.  Every revision question goes RED.
check_needs "H5 a .git that git cannot read is NOT a skip -- every revision question goes red" {
    hrow unreadable
} {{1 0 0} {1 0 0} {1 0 0} {1 0 0} {1 0 0} {1 0 0} {1 0 0}}

## ⚠ A DOWNLOAD PUT BACK UNDER GIT AND COMMITTED IS ASKED, AND IS RED (D14).
## This is the shape two rounds tried to keep green -- `foreign`, then the date
## rule -- and each round failed open.  What resolves in it is verified (G, its
## own commit, {0 0 1}); everything else is REFUSED, the project's c1 and c2
## included, because a history with commits gets no exemption.  S1-fix2's bytes
## scored A, B, C, E and F here as NOT VERIFIED.  G is also what tells this row
## from H4's: a checker that never asked git here would score it {0 1 0}.
check_needs "H8 a download put back under git and COMMITTED is asked and is RED: only its own commit verifies, nothing is skipped" {
    hrow reinit
} {{1 0 0} {1 0 0} {1 0 0} {1 0 0} {1 0 0} {1 0 0} {0 0 1}}

## ⚠ THE CALLER'S GIT_DIR GETS NO VOTE -- the decision recorded above
## istamp::history_probe, held here by measurement.  GIT_DIR and GIT_INDEX_FILE
## are planted, pointing at the FULL fixture, which holds c1 and not f1.  If the
## probe honoured GIT_DIR where there is no .git (it used to), `none` would ask
## git and not come back `none`; if any git call honoured it, the reinit fixture
## would answer from the full fixture's history -- c1 found, f1 not.
check_needs "H10 the caller's GIT_DIR gets no vote: no .git is still none, another repository still answers from its own history" {
    if {$::HF_ERR ne ""} {
        set r "FIXTURES NOT BUILT: $::HF_ERR"
    } else {
        set r [with_fixture_env {
            set ::env(GIT_DIR)        [file join [dict get $::HF full] .git]
            set ::env(GIT_INDEX_FILE) [file join [dict get $::HF full] .git index]
            list [dict get [istamp::history_probe [dict get $::HF none]] state] \
                 [with_repo [dict get $::HF reinit] {
                     list [istamp::history_state] [istamp::rev_exists [dict get $::HF c1]] \
                          [istamp::rev_exists [dict get $::HF f1]]
                 }]
        }]
    }
    set r
} {none {full 0 1}}

## ⚠ NO DATE EXEMPTS ANYTHING -- the row that keeps the date rule from coming
## back.  S1-fix2 skipped an unresolved revision stamped before the history's
## earliest root was authored, and its refuter planted exactly these in a full
## clone: a bogus tree= stamped 2016-09-17 (a one-digit typo of the real date)
## and one stamped 0000-00-00 (no date at all), and both went GREEN.  Planted
## here in the full fixture, whose history began 2026-01-01, every one of them
## is RED:
##   a  bogus, stamped 2016-09-17        before the history began
##   b  bogus, stamped 0000-00-00        not a day: malformed, AND unresolved
##   c  bogus, stamped 2025-12-31        the day before the history began
##   d  tree=c2 + quote=bogus, 2016-09-17  the quote is REFUSED, never skipped
##   e  tree=c1, stamped 2016-09-17      the known POSITIVE: a revision that
##                                       resolves is verified whatever its date
## S1-fix2's bytes: {0 1 0} {0 1 0} {0 1 0} {0 1 1} {0 0 1}.
check_needs "H11 NO DATE EXEMPTS an unresolved revision in a full history -- backdated before it began (2016-09-17, 2025-12-31) or not a day at all (0000-00-00), a bogus tree= or quote= is RED" {
    if {$::HF_ERR ne ""} {
        set r "FIXTURES NOT BUILT: $::HF_ERR"
    } else {
        set c1 [dict get $::HF c1]
        set c2 [dict get $::HF c2]
        set bogus [string repeat deadbeef 5]
        set qb "\n\n```txt quote=$bogus path=a.txt\none\n```"
        set r [with_fixture_env {
            with_repo [dict get $::HF full] {
                list [hverdict "v1 claim=open tree=$bogus stamped=2016-09-17 fix=none open=0"] \
                     [hverdict "v1 claim=open tree=$bogus stamped=0000-00-00 fix=none open=0"] \
                     [hverdict "v1 claim=open tree=$bogus stamped=2025-12-31 fix=none open=0"] \
                     [hverdict "v1 claim=open tree=$c2 stamped=2016-09-17 fix=none open=0" $qb] \
                     [hverdict "v1 claim=open tree=$c1 stamped=2016-09-17 fix=none open=0"]
            }
        }]
    }
    set r
} {{1 0 0} {1 0 0} {1 0 0} {1 0 1} {0 0 1}}

## An UNBORN repository -- `git init`, nothing committed -- is treated as `none`:
## every revision question is NOT VERIFIED by name (there is no commit for one to
## be), and a malformed stamp is still refused.  The probe's side of it, and
## that an orphan branch in a repository WITH history is not this, are H1's.
check_needs "H12 an UNBORN repository skips every revision question by name, and still refuses a malformed stamp" {
    hrow unborn
} {{0 1 0} {0 1 0} {0 1 0} {1 0 0} {0 2 0} {0 2 0} {0 1 0}}

## ONE corpus, five full histories, two readings of "the project's first
## commit" -- computed once here and read by H13 and H14, so that a sabotage of
## the wording shows up in H14 ALONE and a sabotage of the verdict in H13.
## The corpus: c1 (the full fixture's first commit), and a planted bogus tree=
## twice -- backdated to 2016-09-17, and stamped 2026-09-18, the day before
## graft's, orphanc's and rootdate's HEAD-side roots were authored (2026-09-20).
## The two readings: the real project's first commit (upstream_root as shipped,
## in no fixture), and c1 (in full's and graft's stored history only).
## Per history and reading: {state problems skipped verified problems-explained}.
set ::H13 {}
if {$HAVE_GIT && $::HF_ERR eq ""} {
    set h13_bogus [string repeat deadbeef 5]
    set h13_c1 [dict get $::HF c1]
    lassign [mkcorpus h13 [list \
        9001-x.md "# 9001 - x\n\n**STAMP:** `v1 claim=open tree=$h13_c1 stamped=2026-09-18 fix=none open=0`" \
        9002-x.md "# 9002 - x\n\n**STAMP:** `v1 claim=open tree=$h13_bogus stamped=2016-09-17 fix=none open=0`" \
        9003-x.md "# 9003 - x\n\n**STAMP:** `v1 claim=open tree=$h13_bogus stamped=2026-09-18 fix=none open=0`"] ""] h13_id h13_bf
    set h13_rc [catch {with_fixture_env {
        foreach st {full reinit graft orphanc rootdate} {
            with_repo [dict get $::HF $st] {
                foreach reading [list real $h13_c1] {
                    set h13_saved $istamp::upstream_root
                    if {$reading ne "real"} { set istamp::upstream_root $reading }
                    set h13_p [with_corpus $h13_id $h13_bf {istamp::gate}]
                    set istamp::upstream_root $h13_saved
                    set h13_n 0
                    foreach p $h13_p {
                        if {[string first "does not contain the project's first commit" $p] >= 0} { incr h13_n }
                    }
                    dict set ::H13 $st [expr {$reading eq "real" ? "real" : "c1"}] \
                        [list [istamp::history_state] [llength $h13_p] \
                              [llength $istamp::last_skips] $istamp::last_verified $h13_n]
                }
            }
        }
    }} h13_err]
    if {$h13_rc} { set ::H13 "DIED: [lindex [split $h13_err \n] 0]" }
}

## ⚠ (i) AND (iv) OF D14, ASSERTED: EVERY full history skips NOTHING, and a
## planted bogus stamp is RED in each -- the ordinary clone, the download put
## back under git, the graft, the orphan squash and the root-date rewrite.  The
## last four are S1-fix2's refuter's shapes.  S1-fix2's bytes skipped bogus
## stamps -- and in reinit and rootdate, c1 too -- on the date rule, and
## MEASURED against these very fixtures they scored
## {full 1 1 1} {full 0 3 0} {full 0 2 1} {full 0 2 1} {full 0 3 0}.
## ⚠ AND IN THE ORPHAN SQUASH c1 IS REFUSED TOO (D15): it is still in the store
## and on `main`, and it is not in HEAD's history, so a clone of this branch
## would not have it.  S1-fix3's bytes verified it there: {full 2 0 1}.  The
## graft's c1 IS in HEAD's stored history, and is verified.
check_needs "H13 EVERY full history -- a clone, a download put back under git, a graft, an orphan squash, a root-date rewrite -- skips NOTHING, and a planted bogus stamp is RED in each" {
    if {$::HF_ERR ne ""} {
        set out "FIXTURES NOT BUILT: $::HF_ERR"
    } elseif {[string match "DIED:*" $::H13]} {
        set out $::H13
    } else {
        set out {}
        foreach st {full reinit graft orphanc rootdate} { lappend out [lrange [dict get $::H13 $st real] 0 3] }
    }
    set out
} {{full 2 0 1} {full 3 0 0} {full 2 0 1} {full 3 0 0} {full 3 0 0}}

## ⚠ THE RED EXPLAINS ITSELF, AND ONLY THE WORDS CHANGE.  When a revision does
## not resolve in a history that does not contain the project's first commit,
## the problem names the likely cause and the cure (istamp::upstream_note).  With
## the first commit read as c1: full and graft HOLD it (graft's stored history,
## behind the replace ref), so their problems carry no note; reinit, orphanc and
## rootdate lack it, and every problem is explained -- orphanc's refused c1
## included, since "not in HEAD's history" carries the same note (D15).  With
## the real one, no fixture holds it and every problem is explained.  The third column is the
## point of the row: the verdict -- state, problems, skips, verified -- is
## IDENTICAL under both readings in all five histories.  A check that ever
## decided a verdict (S1-fix's `foreign` did) is red here.
check_needs "H14 a red in a history WITHOUT the project's first commit says why -- and the verdict is identical with the note and without it" {
    if {$::HF_ERR ne ""} {
        set out "FIXTURES NOT BUILT: $::HF_ERR"
    } elseif {[string match "DIED:*" $::H13]} {
        set out $::H13
    } else {
        set by_c1 {} ; set by_real {} ; set same 1
        foreach st {full reinit graft orphanc rootdate} {
            set a [dict get $::H13 $st c1]
            set b [dict get $::H13 $st real]
            lappend by_c1   [lindex $a 4]
            lappend by_real [lindex $b 4]
            if {[lrange $a 0 3] ne [lrange $b 0 3]} { set same "$st: [lrange $a 0 3] vs [lrange $b 0 3]" }
        }
        set out [list $by_c1 $by_real $same]
    }
    set out
} {{0 3 0 3 3} {2 3 2 3 3} 1}

## ⚠ A GIT WARNING IS NOT A FAILURE.  S1-fix2's refuter MEASURED a deprecated
## `[core] fsyncObjectFiles = true` in a tester's global config turning a
## pristine full clone `unreadable` -- ten false reds -- because Tcl's exec reads
## ANY stderr as failure.  Planted here on purpose, with GIT_TRACE=2 besides
## (every git writes trace lines to stderr, in every version), around probes of
## the full and unborn fixtures, a revision question and a quote.  The first
## column proves the plant really does make git write to stderr, so the row is
## never vacuous; the rest must read exactly as they do without it.
check_needs "H15 git's WARNINGS are not failures: with a config that makes git warn and GIT_TRACE on, full is full, unborn is unborn, a commit resolves and a quote holds" {
    if {$::HF_ERR ne ""} {
        set h15 "FIXTURES NOT BUILT: $::HF_ERR"
    } else {
        set wcfg [file join [istamp_own [file join $::ISTAMP_SCRATCH_ROOT istamp_[pid]_warncfg]] gitconfig]
        file mkdir [file dirname $wcfg]
        set fh [open $wcfg w] ; puts $fh "\[core\]\n\tfsyncObjectFiles = true" ; close $fh
        set h15 [with_fixture_env {
            set ::env(GIT_CONFIG_GLOBAL) $wcfg
            set h15_tr [expr {[info exists ::env(GIT_TRACE)] ? [list $::env(GIT_TRACE)] : {}}]
            set ::env(GIT_TRACE) 2
            set h15_rc [catch {
                set warns [expr {[catch {exec timeout 30 git -C [dict get $::HF full] rev-parse HEAD} w]
                                 && [regexp {warning:|trace:} $w] ? "warns" : "SILENT: the plant did not reach stderr"}]
                set c1 [dict get $::HF c1]
                list $warns \
                     [dict get [istamp::history_probe [dict get $::HF full]] state] \
                     [dict get [istamp::history_probe [dict get $::HF unborn]] state] \
                     [with_repo [dict get $::HF full] {
                         list [istamp::rev_exists $c1] \
                              [hverdict "v1 claim=open tree=[dict get $::HF c2] stamped=2026-09-18 fix=none open=0" \
                                        "\n\n```txt quote=$c1 path=a.txt\none\n```"]
                     }]
            } h15_out]
            if {[llength $h15_tr]} { set ::env(GIT_TRACE) [lindex $h15_tr 0] } else { unset ::env(GIT_TRACE) }
            if {$h15_rc} { set h15_out "DIED: [lindex [split $h15_out \n] 0]" }
            set h15_out
        }]
    }
    set h15
} {warns full unborn {1 {0 0 1}}}

## ⚠ A SHALLOW BOUNDARY OFF HEAD'S PATH EXCUSES NOTHING (D15).  S1-fix3's
## refuter took a full clone, ran one `git fetch --depth 1` of another branch
## (and, separately, a stranger's `clone --depth 1 -b main` + fetch of this
## branch), planted a bogus tree=, and got ALL PASS with "shallow: history
## absent" -- while every one of HEAD's 5818 commits was present.  offpath is
## that shape in miniature, and must score EXACTLY H2's full vector; eshallow
## (an empty shallow file) and reachroot (a depth that reaches the true root,
## which git lists) must refuse the bogus stamp the same way.
## S1-fix3's bytes scored offpath as shallow: B and G skipped, {0 1 0}.
check_needs "H16 a shallow boundary OFF HEAD's path makes nothing shallow: offpath scores exactly as a full clone, and a bogus stamp is RED there, in an empty shallow file and at a depth that reaches the root" {
    if {$::HF_ERR ne ""} {
        set r "FIXTURES NOT BUILT: $::HF_ERR"
    } else {
        set bogus [string repeat deadbeef 5]
        set r [list [hrow offpath] [with_fixture_env {
            list [with_repo [dict get $::HF eshallow] {
                     hverdict "v1 claim=open tree=$bogus stamped=2026-09-18 fix=none open=0"
                 }] \
                 [with_repo [dict get $::HF reachroot] {
                     hverdict "v1 claim=open tree=$bogus stamped=2026-09-18 fix=none open=0"
                 }]
        }]]
    }
    set r
} {{{0 0 1} {1 0 0} {0 0 1} {1 0 0} {0 0 1} {1 0 1} {1 0 0}} {{1 0 0} {1 0 0}}}

## ⚠ NO TEXT FROM AN ISSUE FILE REACHES git AS AN OPTION (D15).  quote= had no
## grammar, and quote_holds ran `git show <quote>:<path>`: S1-fix3's refuter
## planted ```` ```c quote=--output=<file> path=x ```` and the gate WROTE the file
## -- 21 KB of `git show HEAD` -- during validation, and would in T1 over the
## real corpus.  The locks, and this row measures them:
##   * the gate refuses any quote= that is not a revision token, by name,
##     before git is asked (column 1);
##   * called DIRECTLY with that value -- past the gate's grammar -- each
##     predicate answers "no" (column 2: quote_holds 0, rev_exists 0,
##     rev_is_ancestor -1): rev_exists and rev_is_ancestor check the grammar
##     themselves and pass --end-of-options besides, and since D16 quote_holds
##     puts nothing on git's command line at all -- `<rev>:<path>` goes in on
##     stdin, where `--output=...:x` is merely a name that is "missing";
##   * and nothing at all was written (column 3).
## S1-fix3's bytes wrote the file.
check_needs "H17 no text from an issue file reaches git as an option: quote=--output=<file> is a named problem, the predicates handed it directly refuse it, and NOTHING is written" {
    if {$::HF_ERR ne ""} {
        set r "FIXTURES NOT BUILT: $::HF_ERR"
    } else {
        set pw [istamp_own [file join $::ISTAMP_SCRATCH_ROOT istamp_[pid]_pwned]]
        file delete -force $pw
        file mkdir $pw
        set c2 [dict get $::HF c2]
        set r [with_fixture_env {
            with_repo [dict get $::HF full] {
                ## The target is RELATIVE to the fixture repository git runs in
                ## (`git -C full`): one whitespace-free token even when this
                ## checkout's path holds a space (see Q5), and still $pw/gate for
                ## a regressed checker that handed it to git as an option.
                lassign [mkcorpus h17 [list 9999-x.md "# 9999 - x\n\n**STAMP:** `v1 claim=open tree=$c2 stamped=2026-09-18 fix=none open=0`\n\n```c quote=--output=../../[file tail $pw]/gate path=x\none\n```"] ""] id bf
                set named 0
                foreach p [with_corpus $id $bf {istamp::gate}] {
                    if {[string first "is not a revision" $p] >= 0} { incr named }
                }
                set direct {}
                foreach cmd [list [list istamp::quote_holds --output=[file join $pw qh] x one] \
                                  [list istamp::rev_exists --output=[file join $pw re]] \
                                  [list istamp::rev_is_ancestor --output=[file join $pw ia]]] {
                    if {[catch {uplevel #0 $cmd} a]} {
                        lappend direct "DIED: [lindex [split $a \n] 0]"
                    } else {
                        lappend direct [lindex $a 0]
                    }
                }
                ## D16: a quote's path= is a path IN the revision -- relative, no
                ## `..`, no leading `/` or `-` -- refused by name before git is
                ## asked, the same shape rule as assert='s.
                set c1 [dict get $::HF c1]
                lassign [mkcorpus h17p [list 9999-x.md "# 9999 - x\n\n**STAMP:** `v1 claim=open tree=$c2 stamped=2026-09-18 fix=none open=0`\n\n```txt quote=$c1 path=../a.txt\none\n```\n\n```txt quote=$c1 path=-a.txt\none\n```\n\n```txt quote=$c1 path=/etc/hostname\none\n```"] ""] id2 bf2
                set qpath 0
                foreach p [with_corpus $id2 $bf2 {istamp::gate}] {
                    if {[string first "a quote= block's path=" $p] >= 0} { incr qpath }
                }
                list $named $direct $qpath
            }
        }]
        set written {}
        foreach f [glob -nocomplain -directory $pw *] { lappend written [file tail $f] }
        lappend r [lsort $written]
    }
    set r
} {1 {0 0 -1} 3 {}}

## ⚠ A REVISION MUST BE IN HEAD'S HISTORY, NOT MERELY IN THE STORE (D15).
## S1-fix3's refuter, in the author's own clone: `commit --allow-empty`,
## `reset --soft HEAD~1`, a stamp naming that commit -- CLI `ok`.  Committed, the
## same stamp turned a fresh clone RED, three counted lines in every stranger's
## T1, and nothing had caught it where it was written.  In `amend` that commit
## (am) is in the store and in no ref's history: its tree= is RED, and so is a
## quote= of it, although `git show am:a.txt` finds the text (which is why the
## quote is refused before git show is asked).  c1 is the known POSITIVE: an
## ancestor, verified.  In `shamend` -- the same on the shallow clone -- "not an
## ancestor" cannot be told from "beyond the boundary", so am2 is NOT VERIFIED by
## name, and c2 (HEAD) is still verified.
## S1-fix3's bytes: {0 0 1} {0 0 1} {0 0 1} {0 0 1} {0 0 1}.
check_needs "H18 a revision that resolves but is NOT in HEAD's history -- a commit amended away -- is RED in a full history, a quote= of it too; above a shallow boundary it is NOT VERIFIED by name" {
    if {$::HF_ERR ne ""} {
        set r "FIXTURES NOT BUILT: $::HF_ERR"
    } else {
        set am  [dict get $::HF am]
        set am2 [dict get $::HF am2]
        set c1  [dict get $::HF c1]
        set c2  [dict get $::HF c2]
        set r [with_fixture_env {
            concat [with_repo [dict get $::HF amend] {
                        list [hverdict "v1 claim=open tree=$am stamped=2026-09-18 fix=none open=0"] \
                             [hverdict "v1 claim=open tree=$c1 stamped=2026-09-18 fix=none open=0"] \
                             [hverdict "v1 claim=open tree=$c2 stamped=2026-09-18 fix=none open=0" \
                                       "\n\n```txt quote=$am path=a.txt\none\n```"]
                    }] \
                   [with_repo [dict get $::HF shamend] {
                        list [hverdict "v1 claim=open tree=$am2 stamped=2026-09-18 fix=none open=0"] \
                             [hverdict "v1 claim=open tree=$c2 stamped=2026-09-18 fix=none open=0"]
                    }]
        }]
    }
    set r
} {{1 0 0} {0 0 1} {1 0 1} {0 1 0} {0 0 1}}

## ⚠ D16.3 -- A BOUNDARY THE STORE DOES NOT NEED IS NOT SHALLOW, EVEN AT HEAD.
## S1-fix4's refuter, in the developer's own full clone: one `git fetch --depth 1
## origin fluid-editing` with nothing new writes HEAD into .git/shallow (fdself);
## a fetch of an ancestor ref writes that ancestor (fdanc).  All 5819 commits
## stayed in the store, the probe said `shallow`, and a planted bogus tree= and
## a blob tree= went NOT VERIFIED -- ALL PASS on three arms.  In miniature here:
## each must score EXACTLY H2's full vector -- c1 verified (its ancestry asked
## with the shallow file disregarded, or merge-base would call it "not an
## ancestor"), the bogus stamp and the rotted quote RED.  fdanc, in one gate run
## (hcorpus): c1 verified, the bogus stamp RED, and c2 -- the very commit its
## shallow file names -- verified as an ancestor of HEAD; {problems skipped}
## per file, then the count verified.
## S1-fix4's bytes: fdself scored {0 1 0} for A and B -- skipped, by name.
check_needs "H19 a no-op fetch --depth 1 of HEAD itself, or of an ancestor, makes nothing shallow: the store holds every commit, both check as a full clone does, and a bogus stamp is RED" {
    if {$::HF_ERR ne ""} {
        set r "FIXTURES NOT BUILT: $::HF_ERR"
    } else {
        set bogus [string repeat deadbeef 5]
        set r [list [hrow fdself] [with_fixture_env {
            with_repo [dict get $::HF fdanc] {
                hcorpus [list [list "v1 claim=open tree=[dict get $::HF c1] stamped=2026-09-18 fix=none open=0"] \
                              [list "v1 claim=open tree=$bogus stamped=2026-09-18 fix=none open=0"] \
                              [list "v1 claim=open tree=[dict get $::HF c2] stamped=2026-09-18 fix=none open=0"]]
            }
        }]]
    }
    set r
} {{{0 0 1} {1 0 0} {0 0 1} {1 0 0} {0 0 1} {1 0 1} {1 0 0}} {{0 0} {1 0} {0 0} 2}}

## ⚠ D16.4 -- IN A SHALLOW HISTORY, AN OBJECT THAT IS HERE AND IS NOT A COMMIT IS
## A FINDING.  `cat-file -e X^{commit}` fails alike for "not here" and "here, and
## a blob", and a shallow clone skipped both as "beyond the depth?" (MEASURED by
## S1-fix4's refuter: tree=HEAD:README NOT VERIFIED in --depth 1, fdself, fdanc).
## bl (a.txt's blob) and tr (HEAD's tree) are in the shallow fixture's store:
## RED, each naming its type.  c1 -- a commit beyond the depth -- still skips by
## name, and c2 (HEAD) is still verified -- one gate run, {problems skipped} per
## file then the count verified -- and the two reds name their type.  In the
## full fixture the blob is RED too.
## S1-fix4's bytes scored the shallow blob and tree as skipped: {0 1}.
check_needs "H20 in a SHALLOW history a tree= naming an object that is in the store and is not a commit -- a blob, a tree -- is RED, not skipped; a commit beyond the depth still skips by name" {
    if {$::HF_ERR ne ""} {
        set r "FIXTURES NOT BUILT: $::HF_ERR"
    } else {
        set r [with_fixture_env {
            set sh [with_repo [dict get $::HF shallow] {
                set v [hcorpus [list \
                    [list "v1 claim=open tree=[dict get $::HF bl] stamped=2026-09-18 fix=none open=0"] \
                    [list "v1 claim=open tree=[dict get $::HF tr] stamped=2026-09-18 fix=none open=0"] \
                    [list "v1 claim=open tree=[dict get $::HF c1] stamped=2026-09-18 fix=none open=0"] \
                    [list "v1 claim=open tree=[dict get $::HF c2] stamped=2026-09-18 fix=none open=0"]]]
                set w {}
                foreach {num needle} {9001 "names a blob in this repository, not a commit" 9002 "names a tree in this repository, not a commit"} {
                    set k 0
                    foreach x $::HC_LAST { if {[string match "$num:*" $x] && [string first $needle $x] >= 0} { incr k } }
                    lappend w $k
                }
                list $v $w
            }]
            set fu [with_repo [dict get $::HF full] {
                hcorpus [list [list "v1 claim=open tree=[dict get $::HF bl] stamped=2026-09-18 fix=none open=0"]]
            }]
            concat $sh [list $fu]
        }]
    }
    set r
} {{{1 0} {1 0} {0 1} {0 0} 1} {1 1} {{1 0} 0}}

## ⚠ D16.3 -- AND THE CALLER CANNOT STEER IT.  The probe disregards the shallow
## file by setting GIT_SHALLOW_FILE to "" for one walk; a caller who exports that
## variable (or GIT_NO_LAZY_FETCH) must change nothing.  Planted, inside the
## fixture environment:
##   * GIT_SHALLOW_FILE="" around the SHALLOW fixture: honoured, git would call
##     the repository not shallow and the walk would fail -- `unreadable`; it
##     must still be `shallow` (git_scrub removes the caller's value);
##   * GIT_SHALLOW_FILE naming a file that lists c2 around the FULL fixture, and
##     GIT_NO_LAZY_FETCH=0: still `full`, and c1 still an ancestor of HEAD;
##   * and after every call both variables hold exactly what was planted.
check_needs "H21 the caller's GIT_SHALLOW_FILE and GIT_NO_LAZY_FETCH get no vote: planted, a shallow clone is still shallow, a full one still full with its ancestry intact, and both are put back exactly" {
    if {$::HF_ERR ne ""} {
        set r "FIXTURES NOT BUILT: $::HF_ERR"
    } else {
        set lst [file join [istamp_own [file join $::ISTAMP_SCRATCH_ROOT istamp_[pid]_h21]] shallow]
        file mkdir [file dirname $lst]
        set fh [open $lst w] ; puts $fh [dict get $::HF c2] ; close $fh
        ## GIT_NO_LAZY_FETCH is not one of the fixture environment's names, so
        ## this row puts the suite's own value back itself, on every path.
        set h21_nlf [expr {[info exists ::env(GIT_NO_LAZY_FETCH)] ? [list $::env(GIT_NO_LAZY_FETCH)] : {}}]
        set h21_rc [catch {with_fixture_env {
            set ::env(GIT_SHALLOW_FILE) ""
            set a [dict get [istamp::history_probe [dict get $::HF shallow]] state]
            set a_back [expr {[info exists ::env(GIT_SHALLOW_FILE)] && $::env(GIT_SHALLOW_FILE) eq ""}]
            set ::env(GIT_SHALLOW_FILE) $lst
            set ::env(GIT_NO_LAZY_FETCH) 0
            set b [with_repo [dict get $::HF full] {
                list [istamp::history_state] [istamp::rev_is_ancestor [dict get $::HF c1]]
            }]
            set b_back [expr {[info exists ::env(GIT_SHALLOW_FILE)] && $::env(GIT_SHALLOW_FILE) eq $lst
                              && [info exists ::env(GIT_NO_LAZY_FETCH)] && $::env(GIT_NO_LAZY_FETCH) eq "0"}]
            list $a $a_back $b $b_back
        }} r]
        if {[info exists ::env(GIT_NO_LAZY_FETCH)]} { unset ::env(GIT_NO_LAZY_FETCH) }
        if {[llength $h21_nlf]} { set ::env(GIT_NO_LAZY_FETCH) [lindex $h21_nlf 0] }
        if {$h21_rc} { set r "ROW DIED: [lindex [split $r \n] 0]" }
    }
    set r
} {shallow 1 {full 1} 1}

## ⚠ D19 -- NOTHING IN AN ISSUE FILE CAN MAKE A PARTIAL CLONE FETCH.  Only the
## shallow walk carried GIT_NO_LAZY_FETCH, so in a blob:none clone of a file://
## mirror a tree= naming a blob the clone did not hold ran `git fetch ...
## --filter=blob:none`, `git-upload-pack`, `index-pack --promisor` and
## `maintenance run --auto`, and wrote a new pack into .git (MEASURED by S1-fix6's
## refuter, red-first by S1-fix7, 8 -> 12 pack files; a quote= of an old
## revision did the same through quote_holds).  In `partial`, whose origin
## WOULD serve the blob:
##   A  tree=c2, quote c1:a.txt "one"   -- the blob is not here: NOT VERIFIED, by
##      name (a partial clone's gap), never RED and never fetched
##   B  tree=c2, quote c1:nope.txt      -- a path c1 never had: RED
##   C  tree=c2, quote c2:b.txt WRONG   -- the blob IS here: a rotted quote, RED
##   D  tree=c2, quote c2:b.txt "two"   -- the known positive
##   E  tree=<c1:a.txt's blob, in full> -- does not resolve here: RED
##   G  tree=c2, quote=<a revision that exists nowhere> path=a.txt -- RED: only
##      a VERIFIED revision's missing content is ever excused as a gap
## then F, in `nopromise` (NOT a partial clone, the same blob missing): quote A
## is RED -- the gap is a partial clone's, and nothing else earns it.
## As {the state, those per-file {problems skipped} plus the verified count,
## the one skip naming the partial clone, F's {problems skipped} and verified
## count, the blob STILL absent afterwards, the pack count unchanged}.
check_needs "H22 no git call fetches: in a blob:none partial clone whose origin would serve the blob, a quote of content not in the checkout is NOT VERIFIED by name, a missing path and a rotted quote are RED, a tree= naming the absent blob is RED -- and afterwards the blob is still absent" {
    if {$::HF_ERR ne ""} {
        set r "FIXTURE NOT BUILT: $::HF_ERR"
    } else {
        set pd [dict get $::HF partial]
        set c1 [dict get $::HF c1]
        set c2 [dict get $::HF c2]
        set bl [dict get $::HF bl]
        set st "v1 claim=open tree=$c2 stamped=2026-09-18 fix=none open=0"
        set r [with_fixture_env {
            set packs0 [llength [glob -nocomplain -directory [file join $pd .git objects pack] *]]
            set v [with_repo $pd {
                list [istamp::history_state] \
                     [hcorpus [list [list $st "\n\n```txt quote=$c1 path=a.txt\none\n```"] \
                                    [list $st "\n\n```txt quote=$c1 path=nope.txt\none\n```"] \
                                    [list $st "\n\n```txt quote=$c2 path=b.txt\nWRONG\n```"] \
                                    [list $st "\n\n```txt quote=$c2 path=b.txt\ntwo\n```"] \
                                    [list "v1 claim=open tree=$bl stamped=2026-09-18 fix=none open=0" ""] \
                                    [list $st "\n\n```txt quote=[string repeat deadbeef 5] path=a.txt\none\n```"]]] \
                     [llength [lsearch -all -glob $istamp::last_skips "9001:*partial clone*"]]
            }]
            lappend v [with_repo [dict get $::HF nopromise] {
                hcorpus [list [list $st "\n\n```txt quote=$c1 path=a.txt\none\n```"]]
            }]
            set still [catch {exec env GIT_NO_LAZY_FETCH=1 timeout 30 git -C $pd cat-file -e $bl 2>/dev/null}]
            set packs1 [llength [glob -nocomplain -directory [file join $pd .git objects pack] *]]
            list {*}$v $still [expr {$packs1 == $packs0}]
        }]
    }
    set r
} {full {{0 1} {1 0} {1 0} {0 0} {1 0} {1 0} 5} 1 {{1 0} 1} 1 1}

## ⚠ D16.5 -- FENCES CLOSE THE COMMONMARK WAY, END TO END.  S1-fix4's refuter
## planted a 4-backtick quote fence holding an inner ``` line and, below it, a
## rotted line: the checker closed the block at the inner line, verified only
## what was above it, and said `ok (0 problems)` -- markdown renders all of it as
## the quote.  On the full fixture (tree=c2; the quote is of c1:a.txt = "one"):
##   a  ````-fence: one, ```, two      RED -- the whole body is checked
##   b  ````-fence: one                GREEN -- the known positive
##   c  a ```-quote inside a ~~~ block  RED -- it is text there, and is named
##   d  ```-fence closed by "  ```"     GREEN -- a closer may be indented 3
## One gate run: {problems skipped} per file, then the count verified (4 tree=).
## S1-fix4's bytes: a {0 0} (the silent pass) and d {1 0} (never closed).
check_needs "Q7 RED: quote fences close the CommonMark way -- a rotted line after an inner ``` in a 4-backtick fence is refused, a quote that is text inside a ~~~ block is named; a longer or indented closer closes" {
    if {$::HF_ERR ne ""} {
        set r "FIXTURES NOT BUILT: $::HF_ERR"
    } else {
        set c1 [dict get $::HF c1]
        set st "v1 claim=open tree=[dict get $::HF c2] stamped=2026-09-18 fix=none open=0"
        set r [with_fixture_env {
            with_repo [dict get $::HF full] {
                hcorpus [list [list $st "\n\n````txt quote=$c1 path=a.txt\none\n```\ntwo\n````"] \
                              [list $st "\n\n````txt quote=$c1 path=a.txt\none\n````"] \
                              [list $st "\n\n~~~\n```txt quote=$c1 path=a.txt\ntwo\n```\n~~~"] \
                              [list $st "\n\n```txt quote=$c1 path=a.txt\none\n  ```\ntwo"]]
            }
        }]
    }
    set r
} {{1 0} {0 0} {1 0} {0 0} 4}

## This tree's own verdict, against the evidence on disk.  The probe asks git;
## this reads files git writes.  A probe that ever called a full clone shallow
## -- and so quietly retired G4 and D9h -- is red HERE, by name.  Nothing on
## disk says whether a history is complete; H1's broken fixtures hold the probe
## to that, and in `unreadable` this row is red, as that state's every
## revision question is.  Any shallow file admits either verdict
## (`shallowrepo`): whether the store holds what lies beyond a boundary is not
## in any file git writes as text, and H1/H16/H19 hold the probe to that instead.
set H6_DISK [istamp_disk_evidence $ROOT]
check "H6 this tree's history verdict agrees with the evidence on disk (.git, git's own shallow file, an unborn HEAD)" \
    [expr {$HSTATE in [istamp_disk_admits $H6_DISK] ? $H6_DISK : "$HSTATE, which the disk ($H6_DISK) does not admit"}] \
    $H6_DISK

## ⚠ THE REAL CORPUS, ASKED OF GIT DIRECTLY -- not through the gate.  Every
## stamped revision resolves here.  D9 asks the same question through the
## checker's rules; this asks it without them.  If the checker ever grows an
## exemption again -- S1-fix's `foreign` and S1-fix2's date rule were each one
## -- D9 can go green on a history that holds none of the stamps, and THIS row
## names every one.  In `unreadable` nothing resolves and the row is red, as
## that state's every revision question is.  ⚠ AND "RESOLVES" MEANS "IS IN
## HEAD'S HISTORY" (D15): a commit amended away still resolves in the author's
## own store, and every other clone is without it.
check_needs "H9 every stamped revision in the real corpus resolves here and is in HEAD's history -- asked of git directly, not through the gate" {
    set h9_off {}
    if {$CORPUS_DP ne ""} { lappend h9_off "NOT-READ: $CORPUS_DP" }
    foreach st $D9_STAMPS {
        lassign $st num tree stamped
        set r [dict get $D9_RESOLVES $tree]
        if {$r ne "ok"} { lappend h9_off "$num:$tree ($r)" }
    }
    list [expr {$D9_NSTAMPED > 0}] $h9_off
} {1 {}}

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
## When a read-only checkout sent this run's directories to the temp root, that
## root is this run's own, made by it, and goes with them.
catch {istamp_delete_own $::ISTAMP_OWN_DIRS}
set ::ISTAMP_OWN_DIRS {}
if {$::ISTAMP_TEMP_ROOT ne ""} { catch {istamp_delete_own [list $::ISTAMP_TEMP_ROOT]} }
catch {istamp_sweep_corpses $::ISTAMP_SHARED_SCRATCH}
## ...and a temp root left by a run that died in a read-only checkout: only that
## one name, only a dead owner's, only past the age floor.
set tmpdir /tmp
if {[info exists ::env(TMPDIR)] && [file isdirectory $::env(TMPDIR)]} { set tmpdir $::env(TMPDIR) }
catch {istamp_sweep_corpses [file normalize $tmpdir] 300 {istamp_[0-9]*_tmproot}}

## ⚠ THE LAST ROW, AND THE ONE THAT KEEPS EVERY SKIP HONEST.  The set of rows
## that skipped must be EXACTLY the set declared above for this tree's state --
## in a full clone, EMPTY.  A row that starts skipping without being declared,
## a declared row that silently stops skipping, or a full clone that skips
## anything at all, is red here by name.
set H7_WANT {}
if {$HSTATE in {shallow none unborn}} { lappend H7_WANT {*}$NEEDS_DEPTH }
if {$HSTATE in {none unborn}}         { lappend H7_WANT {*}$NEEDS_REPO }
if {!$HAVE_GIT}                       { lappend H7_WANT {*}$NEEDS_GITBIN }
## ⚠ AND "GIT IS NOT INSTALLED" MUST BE TRUE WHEN IT IS CLAIMED.  The skipped set
## was held to the declared set, but the declared set trusted HAVE_GIT -- so a
## one-word break of the git check (`git --version` -> `gti --version`, MEASURED
## by S1-fix's refuter) skipped all ten NEEDS_GITBIN rows in a FULL clone, the
## write guard H0 among them, and H7 agreed with it: ALL PASS, rc 0.  The probe
## had just run git to call the tree `full`.  So H7 also demands that the two
## agree: `full`, `shallow` and `unborn` can only come from a git that RAN, and
## HAVE_GIT=0 beside any of them is a broken git check, red here by name.
set H7_GIT [expr {$HAVE_GIT || $HSTATE ni {full shallow unborn}
                  ? "consistent"
                  : "HAVE_GIT is 0, but git ran: the history probe called this tree '$HSTATE'"}]
check "H7 the rows that skipped are EXACTLY the declared set for '$HSTATE' -- in a full clone, none -- and 'git is not installed' is never claimed where git ran" \
    [list [lsort -unique $::SKIPPED] $H7_GIT] \
    [list [lsort -unique $H7_WANT] consistent]

## A skipping run still ends in the banner every reader accepts -- exit 0 and a
## whole-line `OVERALL: ok` (tests/banner_rule.tcl) -- because a skip is not a
## failure.  It is not hidden either: each skipped row printed its own `skip:`
## line, and the count and the reason ride in the RESULT trailer, the shape
## test_ase_bus_bits_0159 already ships (`RESULT: ALL PASS (12 checks, 2
## group(s) skipped)`).
##
## The trailer names EVERY cause that skipped something, not just the history
## state: with git missing from an export it used to read `10 skipped -- none:
## history absent` while five of the ten were "git is not installed".
set nskip [llength $::SKIPPED]
set skip_causes {}
set skip_whys   {}
foreach id $::SKIPPED {
    if {$id in $NEEDS_GITBIN} {
        set cause "git not installed"
        set why   "git is not installed, so the H rows could not build their fixture repositories"
    } else {
        set cause [expr {$HSTATE eq "unborn" ? "unborn: no commits yet" : "$HSTATE: history absent"}]
        set why   $HWHY
    }
    if {$cause ni $skip_causes} { lappend skip_causes $cause ; lappend skip_whys $why }
}
if {$nskip} {
    puts "## $nskip ROW(S) SKIPPED, AND A SKIPPED ROW VERIFIED NOTHING: [join $::SKIPPED {, }]"
    foreach why $skip_whys { puts "## why: $why" }
    puts "## run this suite in a full clone of this project (git clone with no --depth), with git installed, to verify them."
}
set trailer [expr {$nskip ? ", $nskip skipped -- [join $skip_causes {; }]" : ""}]
if {$fail == 0} {
    puts "RESULT: ALL PASS ($npass checks$trailer)"
    puts "OVERALL: ok"
    exit 0
} else {
    puts "RESULT: $fail FAILED ($npass passed$trailer)"
    puts "OVERALL: notok"
    exit 1
}
