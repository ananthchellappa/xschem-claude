## File: tests/headless/issue_stamp.tcl
##
## THE ISSUE-STAMP CHECKER.  Spec: doc/claude/specs/issue_stamp.md
##
## WHAT THIS IS FOR.  doc/claude/issues/ is 1047 numbered files and 12 MB of
## prose, and until this file landed NOTHING mechanical read any of it.  The
## measured consequence (issue-tracker batch, 2026-09-17, four crews on a
## pre-registered random sample of 40):
##
##     ROTTED-CITE  27 of 40      <- the dominant defect, by a wide margin
##     STALE-FIXED   7 of 40
##     BAD-FIX       1 of 40
##     STALE-OPEN    0 of 40
##
## So the tracker's disease is NOT that it describes the wrong code.  It is that
## it POINTS AT THE WRONG PLACE, and that nothing ever notices when a defect is
## fixed under a different number.
##
## WHY A RETROSPECTIVE ROT CHECKER IS IMPOSSIBLE, AND THIS IS NOT ONE.
## Three separate cheap checks were tried and all three found nothing usable:
##   * "does the cited line exist?"  -> citescan.py: 3751 citations, PAST-EOF = 0.
##     Nothing in the tracker points past an end of file.  The rot is always a
##     citation that RESOLVES and whose text moved.
##   * "is the cited symbol still there?" -> symbolscan.py: 2016 backticked
##     foo() citations, 98.4% still present.  Symbols do not rot.
##   * "does the quoted line match the file?" -> quotescan.py called 17 of 20
##     rotted; SIXTEEN were the heuristic grabbing SPICE decks and log excerpts.
## You cannot compute, today, what a sentence meant when it was written.  You CAN
## make every sentence written from now on say what it was measured against, and
## then check THAT.  This file checks that.  It is a ratchet, not an audit.
##
## THE ONE MEASUREMENT THE WHOLE DESIGN RESTS ON.  Of the sampled files, five
## carried bare `file:line` citations and 5 of 5 had rotted; three cited only
## symbols and 3 of 3 still pointed at the right place.  Exactly one file --
## number 0818 -- cited `file:line` AND NAMED THE REVISION, whereupon
##
## ⚠ THAT SENTENCE IS PHRASED THE WAY IT IS ON PURPOSE.  Its first draft read
## "3 of 3 still resolved; and exactly one -- issue 0818 -- cited", and the
## driver's closure detector (tools/closescan.py) promptly reported
## "0818 <- claimed closed by: tests/headless/issue_stamp.tcl".  A citation
## RESOLVING is not an issue being RESOLVED, but a regex over English cannot
## tell, and a file written twenty minutes earlier silently changed a corpus-wide
## census from 165/7 to 166/8.  That is why closure is a DECLARED field (super=)
## in this design and never an inference over prose.
##     git show fadb226d:src/scheduler.c | sed -n '851p;10559p;13202p;13787p'
## reproduced all four dead coordinates EXACTLY.  One revision name, recorded
## once at the top of a file, makes every coordinate in that file recoverable
## forever.  That is the stamp's `tree=` field and it is the reason this exists.
##
## ⚠ THE STAMP IS A STATEMENT ABOUT THE PAST, AND THAT IS WHY IT NEVER ROTS.
## `tree=` does not mean "current".  It means "the claims in this file were last
## checked against this revision".  That sentence is true forever; it only gets
## OLDER, which is information rather than error.  A checker that demanded
## tree=HEAD would redden the entire corpus the moment anyone committed -- which
## is exactly how this batch's own PLAN.md:3 rotted WITHIN THE HOUR, because the
## driver committed twice while crews were reading it.  Do not "improve" this by
## comparing tree= to HEAD.  That is not a stricter check, it is the defect.
##
## ⚠ WHAT THIS CHECKER CANNOT SEE, stated here because a validator whose blind
## spot is undocumented is worse than none.  It reads a HEADER block and marked
## fenced blocks.  The single highest-consequence rot measured in the sample was
## BELOW THE FOLD: issue 0071's header is correct and open, while its section 3
## lists 0063 as an unresolved HIGH (0063 itself reads "REPLAYABLE"), its
## section 4 calls 0003 "pre-existing" (0003 reads CLOSED), and its "next
## mutators to convert" list of six is five done.  Umbrella issues are what
## people read to pick work.  The `mirror` check below is the partial answer --
## it refuses a file that RESTATES another issue's status, which is the motion
## that creates that rot -- but it can only compare two stamps, so it is blind
## until both files are stamped.  Prose below the fold is not validated and this
## file does not pretend otherwise.
##
## GREEN BY CONSTRUCTION ON THE DAY IT LANDED, AND STILL ABLE TO GO RED.
## Enforcement is FORWARD ONLY.  A file that carries a stamp is validated against
## the grammar; a file that does not is grandfathered BY NAME in
## issue_stamp_baseline.txt.  A NEW issue file whose number is not in that
## baseline and which carries no stamp is a FAIL.  The unconverted set can
## therefore shrink but never grow, and nothing is red on day one.
##
## ⚠ THE BASELINE IS A LIST OF NUMBERS, NOT A COUNT, AND THAT IS DELIBERATE.
## A count-based non-regression gate passes when one grandfathered file is
## deleted and one unstamped file is added.  This is the harness batch's W12b
## lesson -- a shared namespace cannot be scored by counting, only by identity --
## and this batch reproduced it twice more (a `pgrep -af` that matches itself; a
## `grep -lieE` that swallowed its own pattern and "measured" 1050 files out of
## 1047).  Match by identity.  Always.
##
## ⚠ AND A VACUOUS GREEN IS A BROKEN CHECKER WEARING A PASS.  There are zero
## stamped files today, so every forward check has an empty input set and would
## report success while doing nothing -- the exact family of failure that
## produced five wrong driver measurements in one evening, every one of them a
## command that returned a plausible number without doing what was meant.  So
## `gate` SELF-TESTS FIRST against known-answer fixtures and reports NOTHING if
## it fails them.  A green from this file means the parser was exercised.
##
## USAGE
##     tclsh tests/headless/issue_stamp.tcl gate      # the verdict (exit 0/1)
##     tclsh tests/headless/issue_stamp.tcl report    # advisory census, exit 0
##     tclsh tests/headless/issue_stamp.tcl selftest  # fixtures only
## or, as a library (this is what test_issue_stamp.tcl does):
##     set ::ISSUE_STAMP_LIB 1
##     source [file join [file dirname [info script]] issue_stamp.tcl]
##
## It needs no xschem, no display, no simulator and no T1 run: it reads files and
## shells out to git and grep.  It runs under plain tclsh AND under
## `xschem --nogui --pipe -q --script`, so full_audit.sh's ls-based discovery and
## run_suites.sh both work unchanged.
##
## ⚠ EVERY exec HERE IS WRAPPED IN `timeout`.  The in-suite Tcl watchdog cannot
## interrupt a blocking exec (row W13 of test_suite_watchdog_1403.tcl pins that
## limitation by measurement), and an unbounded wait in this project once cost
## 8 h 7 min (issue 1403).  A stall must be a named outcome, never silence.

namespace eval istamp {
    ## ⚠ CAPTURED HERE, AT SOURCE TIME, AND NEVER RE-READ.  `info script` returns
    ## whatever file the interpreter is executing AT THE MOMENT IT IS CALLED, so
    ## deriving the repo inside init() meant that a driver script living anywhere
    ## else resolved the repo two levels above ITSELF.  git -C then pointed at a
    ## non-repository, every rev_exists() came back false, and a perfectly valid
    ## stamp was reported as "tree= does not resolve to a commit in this repo".
    ## A PLAUSIBLE RED FROM A BROKEN COMMAND -- the exact family of failure this
    ## checker exists to catch, produced by the checker, on its first outing.  It
    ## was caught only because the revision under test was one already known to
    ## be good.  Row S20 locks it.
    variable home [file dirname [file normalize [info script]]]
    variable repo       ""
    variable issues_dir ""
    variable baseline   ""

    ## The vocabularies.  Deliberately tiny and CLOSED: an unknown key is an
    ## error, not an extension point.  A typo that is silently ignored is a
    ## stamp that lies, and this corpus does not need more of those.
    ##
    ## ⚠ THE SELF-TEST BELOW CARRIES KNOWN NEGATIVES AS WELL AS KNOWN POSITIVES,
    ## and that is not symmetry for its own sake.  A self-test asserting only
    ## that the check FIRES proves nothing about whether it OVER-fires -- and on
    ## a 1047-file corpus an over-firing checker is worse than none, because it
    ## gets disabled.  Measured the same day on the sibling tool: closescan.py
    ## self-tested one true positive, and 4 of the 7 issues it then reported as
    ## "closed but still marked open" were false.  Two of the four literally read
    ## "FILED, **not** closed: issue NNNN" -- the negation sitting inside the
    ## regex's own 40-character gap -- so acting on that table would have marked
    ## two genuinely open defects closed, one of them carrying a live user
    ## ruling.  The real rate was 1 in 165, not 7.
    variable ok_claim {open fixed partial latent duplicate wontfix}
    variable ok_fix   {none untried taken superseded partial}
    ## `scope=` names the arm, path or door a claim is scoped to, for the defect
    ## that is closed on ONE route and live on another.  Measured cases: 0216 is
    ## fixed for the Location bar and for wviewer::restore but NOT for the ASE
    ## re-run path (src/results.tcl says so in its own voice: "Converting that
    ## path is NOT this item"), and 0650's general channel landed at `5dd68128`
    ## while its titular session-window sink did not -- 0655 carries the
    ## remainder, "deferred out of issue 0650 deliberately".  Without a scope
    ## these two get closed wrongly by whoever tidies next, and closing them
    ## wrongly is the STALE-OPEN direction: the dangerous one.
    variable ok_key   {claim tree stamped fix open super by scope}
    variable req_key  {claim tree stamped fix open}

    ## Timeouts, seconds, for the three things we shell out to.
    variable t_git   30
    variable t_grep  60
}

## ⚠ THE PARAMETER IS NOT CALLED `repo`.  `variable repo` inside a proc that
## already has a local named `repo` is a hard error ("variable already exists"),
## and the proc is the one every entry point calls first -- so the whole file
## died at load with a message about a variable rather than about anything real.
proc istamp::init {{rootdir ""}} {
    variable repo
    variable issues_dir
    variable baseline
    variable home
    if {$rootdir eq ""} {
        # tests/headless/issue_stamp.tcl -> repo root is two levels up from the
        # CHECKER's own directory, captured at source time. Never [info script].
        set repo [file dirname [file dirname $home]]
    } else {
        set repo [file normalize $repo]
    }
    set issues_dir [file join $repo doc claude issues]
    set baseline   [file join $repo tests headless issue_stamp_baseline.txt]
    return $repo
}

## ---------------------------------------------------------------------------
## THE GRAMMAR
## ---------------------------------------------------------------------------
##
## One physical line, anchored at column 0, never wrapped:
##
##   **STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=3`
##
## ⚠ "ONE PHYSICAL LINE" IS A MEASURED REQUIREMENT, NOT A STYLE PREFERENCE.
## The nearest thing the corpus already has is the prose "measured in the tree at
## `aa0e2213`" that 1473/1477/1478/1479 open with -- and a census of it MISSED
## ALL FOUR, because markdown hard-wraps the phrase across a newline and a
## line-oriented grep cannot match it.  The driver published "only 1 file in 1047
## states its tree" having READ those four files in the same session.  A
## convention a grep cannot see is a convention that does not exist.

proc istamp::parse_stamp {line} {
    variable ok_claim
    variable ok_fix
    variable ok_key
    variable req_key

    if {![regexp {^\*\*STAMP:\*\*[ \t]+`([^`]*)`[ \t]*$} $line -> body]} {
        return [dict create ok 0 err "not a STAMP line" f {}]
    }
    set toks {}
    foreach t [split [string trim $body]] {
        if {$t ne ""} { lappend toks $t }
    }
    if {[llength $toks] == 0} {
        return [dict create ok 0 err "empty stamp" f {}]
    }
    set ver [lindex $toks 0]
    if {$ver ne "v1"} {
        return [dict create ok 0 err "first token must be the schema version `v1`, got `$ver`" f {}]
    }
    set f [dict create]
    foreach t [lrange $toks 1 end] {
        if {![regexp {^([a-z]+)=(.*)$} $t -> k v]} {
            return [dict create ok 0 err "token `$t` is not key=value" f {}]
        }
        if {[lsearch -exact $ok_key $k] < 0} {
            return [dict create ok 0 err "unknown key `$k` (known: $ok_key)" f {}]
        }
        if {[dict exists $f $k]} {
            return [dict create ok 0 err "duplicate key `$k`" f {}]
        }
        dict set f $k $v
    }
    foreach k $req_key {
        if {![dict exists $f $k]} {
            return [dict create ok 0 err "missing required key `$k`" f $f]
        }
    }
    set claim [dict get $f claim]
    if {[lsearch -exact $ok_claim $claim] < 0} {
        return [dict create ok 0 err "claim=$claim is not one of: $ok_claim" f $f]
    }
    set fix [dict get $f fix]
    if {[lsearch -exact $ok_fix $fix] < 0} {
        return [dict create ok 0 err "fix=$fix is not one of: $ok_fix" f $f]
    }
    set tree [dict get $f tree]
    ## The a-f requirement is stolen from tools/stampscan.py, and it is there
    ## because a bare [0-9a-f]{8,40} matched 16091816 (a MemTotal in kB) and
    ## 141592654 (pi) and produced a driver finding that "193 of 508 cited SHAs
    ## do not resolve".  They were not SHAs.
    if {![regexp {^[0-9a-f]{7,40}$} $tree] || ![regexp {[a-f]} $tree]} {
        return [dict create ok 0 err "tree=$tree is not a revision (7-40 hex, at least one a-f)" f $f]
    }
    if {![regexp {^[0-9]{4}-[0-9]{2}-[0-9]{2}$} [dict get $f stamped]]} {
        return [dict create ok 0 err "stamped=[dict get $f stamped] is not YYYY-MM-DD" f $f]
    }
    if {![regexp {^(0|[1-9][0-9]*)$} [dict get $f open]]} {
        return [dict create ok 0 err "open=[dict get $f open] is not a non-negative integer" f $f]
    }
    ## ⚠ A SUPERSEDED FIX MUST NAME WHAT REPLACED IT.  This rule exists because
    ## of issue 0442, and 0442 is the sharpest defect in the whole sample: its
    ## numbered item 1 was ACCURATE WHEN WRITTEN, the tree then fixed the defect
    ## by the unnumbered alternative buried at the end of the same section, and
    ## pasting item 1 today RE-INTRODUCES what was deliberately deleted.  No
    ## status field catches that, because the status was never wrong.  Only
    ## "which option was taken" catches it.
    if {$fix eq "superseded" || $claim eq "duplicate"} {
        if {![dict exists $f super]} {
            return [dict create ok 0 err \
                "fix=superseded / claim=duplicate must name what replaced it: super=NNNN" f $f]
        }
    }
    ## ⚠ `self` IS IN THIS GRAMMAR BECAUSE THE WORKED EXAMPLE REFUTED THE FIRST
    ## DRAFT, which required a 4-digit issue number.  0442 -- the case the whole
    ## `fix=superseded` rule was written for -- was superseded by an UNNUMBERED
    ## alternative buried at the end of its own fix section.  There is no issue
    ## number to name.  A grammar that cannot express its own motivating example
    ## is a grammar that gets worked around, so: an issue number, a revision, or
    ## `self`.
    if {[dict exists $f scope] && ![regexp {^[A-Za-z0-9._/-]+$} [dict get $f scope]]} {
        return [dict create ok 0 err \
            "scope=[dict get $f scope] must be a single token naming an arm, path or door" f $f]
    }
    if {[dict exists $f super]} {
        set s [dict get $f super]
        set ok_super [expr {[regexp {^[0-9]{4}$} $s]
                            || $s eq "self"
                            || ([regexp {^[0-9a-f]{7,40}$} $s] && [regexp {[a-f]} $s])}]
        if {!$ok_super} {
            return [dict create ok 0 err \
                "super=$s must be a 4-digit issue number, a revision, or `self`" f $f]
        }
    }
    return [dict create ok 1 err "" f $f]
}

## Format a field dict back into a stamp line.  Used by `restamp` and by the
## fixtures, so the writer and the reader can never drift apart.
proc istamp::format_stamp {f} {
    set out "v1"
    foreach k {claim tree stamped fix open super by} {
        if {[dict exists $f $k]} { append out " $k=[dict get $f $k]" }
    }
    return "**STAMP:** `$out`"
}

## ---------------------------------------------------------------------------
## FILE SCANNING
## ---------------------------------------------------------------------------

proc istamp::read_file {path} {
    set fh [open $path r]
    fconfigure $fh -encoding utf-8
    set t [read $fh]
    close $fh
    return $t
}

## Find the stamp in a file's text.  Returns a dict:
##   n      -- how many stamp-shaped lines the WHOLE file carries
##   line   -- the first one's text ({} if none)
##   lineno -- its 1-based line number (0 if none)
## The header window is enforced by the caller, not here, so that a stamp buried
## at the bottom is reported as a misplaced stamp rather than as no stamp at all.
proc istamp::find_stamp {text} {
    set n 0; set first {}; set firstno 0; set i 0
    foreach ln [split $text \n] {
        incr i
        ## ANCHORED, and never `string match` -- in a glob pattern the stamp's
        ## own leading `**` are two WILDCARDS, so `string match {**STAMP:** *}`
        ## matches any line that merely MENTIONS the token, including this
        ## comment.  A pattern that matches itself is how `pgrep -af
        ## run_regression` came to report four hits for one run.
        if {[regexp {^\*\*STAMP:\*\*} $ln]} {
            incr n
            if {$n == 1} { set first $ln; set firstno $i }
        }
    }
    return [dict create n $n line $first lineno $firstno]
}

## Marked fenced blocks.  The info string after the language word takes the same
## key=value grammar as the stamp:
##
##   ```c quote=fadb226d path=src/scheduler.c      <- a verifiable quote
##   ```tcl fix=superseded                          <- a prescription's state
##   ```sh assert=absent pat=SABOTAGE path=src/ state=broken
##
## Returns a list of dicts: kind, attrs, body, lineno.
proc istamp::find_blocks {text} {
    set out {}
    set i 0
    set in 0
    set attrs {}
    set body {}
    set startno 0
    foreach ln [split $text \n] {
        incr i
        if {!$in} {
            if {[regexp {^```+[ \t]*(.*)$} $ln -> info]} {
                set toks {}
                foreach t [split [string trim $info]] {
                    if {[regexp {^([a-z]+)=(.*)$} $t -> k v]} { lappend toks $k $v }
                }
                set in 1; set attrs $toks; set body {}; set startno $i
            }
        } else {
            if {[regexp {^```+[ \t]*$} $ln]} {
                set in 0
                if {[llength $attrs]} {
                    lappend out [dict create attrs $attrs body [join $body \n] lineno $startno]
                }
            } else {
                lappend body $ln
            }
        }
    }
    return $out
}

## ---------------------------------------------------------------------------
## THE TREE PREDICATES -- the only things here that touch the repo
## ---------------------------------------------------------------------------

proc istamp::rev_exists {rev} {
    variable repo
    variable t_git
    if {[catch {exec timeout $t_git git -C $repo cat-file -e ${rev}^{commit}} m opt]} {
        return 0
    }
    return 1
}

## Does `git show <rev>:<path>` contain this text?  Whitespace-normalised on
## both sides, because a quote that was re-indented is not a rotted quote.
##
## THIS IS THE CHECK FOR THE CLASS NOTHING ELSE CATCHES.  A stale line number
## LOOKS stale the moment you follow it.  A stale quoted code block still looks
## like valid C and reads as authoritative -- issues 0296 and 0435 both quote C
## that no longer exists, and A1's phrase for 0435 is exactly right: "correct by
## reference, damaging by paste".  Neither was even scored BAD-FIX, which means
## the count of dangerous stored fixes in this tracker is an UNDERCOUNT.
proc istamp::quote_holds {rev path body} {
    variable repo
    variable t_git
    if {[catch {exec timeout $t_git git -C $repo show ${rev}:${path}} src]} {
        return [list 0 "git show ${rev}:${path} failed"]
    }
    set n_src  [regsub -all {[ \t\r\n]+} $src  { }]
    set n_body [string trim [regsub -all {[ \t\r\n]+} $body { }]]
    if {$n_body eq ""} { return [list 0 "empty quote block"] }
    if {[string first $n_body $n_src] >= 0} { return [list 1 ""] }
    return [list 0 "quoted text is not in ${rev}:${path}"]
}

## Evaluate a declared assertion about the tree.  Vocabulary is two predicates
## and one pattern token; there is no shell, no interpolation and no way to
## express anything but a grep.  That is on purpose: a document that can run
## arbitrary commands when you validate it is a document you cannot validate.
##
## Returns [list holds_p hits detail].
proc istamp::assert_eval {kind pat path} {
    variable repo
    variable t_grep
    set target [file join $repo $path]
    set hits 0
    set out ""
    if {[catch {set out [exec timeout $t_grep /usr/bin/grep -rn -- $pat $target]} m opt]} {
        ## grep exits 1 for "no match", which is a RESULT, not an error.  Any
        ## other nonzero is an infrastructure failure and must not be silently
        ## read as "no match" -- that is issue 1479's class exactly: a job that
        ## never executed counted as an ordinary answer.
        set ec [dict get $opt -errorcode]
        set code [expr {[lindex $ec 0] eq "CHILDSTATUS" ? [lindex $ec 2] : -1}]
        if {$code == 1} {
            set hits 0
        } else {
            return [list -1 -1 "grep failed (exit $code) on $path"]
        }
    } else {
        set hits [llength [split [string trim $out] \n]]
        if {[string trim $out] eq ""} { set hits 0 }
    }
    if {$kind eq "absent"} {
        return [list [expr {$hits == 0}] $hits ""]
    } elseif {$kind eq "present"} {
        return [list [expr {$hits > 0}] $hits ""]
    }
    return [list -1 -1 "unknown assert kind `$kind`"]
}

## ---------------------------------------------------------------------------
## THE BASELINE -- identity, not a count
## ---------------------------------------------------------------------------

proc istamp::load_baseline {} {
    variable baseline
    set s {}
    if {![file exists $baseline]} { return [list 0 $s] }
    foreach ln [split [read_file $baseline] \n] {
        set ln [string trim $ln]
        if {$ln eq "" || [string index $ln 0] eq "#"} { continue }
        if {[regexp {^[0-9]{4}$} $ln]} { dict set s $ln 1 }
    }
    return [list 1 $s]
}

proc istamp::issue_files {} {
    variable issues_dir
    set out {}
    foreach f [lsort [glob -nocomplain -tails -directory $issues_dir *.md]] {
        if {[regexp {^([0-9]{4})-.*\.md$} $f -> num]} { lappend out $num $f }
    }
    return $out
}

## ---------------------------------------------------------------------------
## THE GATE
## ---------------------------------------------------------------------------
##
## Returns a list of problem strings.  Empty list = green.
## `opts` may carry -headerlines N (default 12).

proc istamp::gate {args} {
    variable issues_dir
    variable ok_claim
    set headerlines 12
    foreach {k v} $args { if {$k eq "-headerlines"} { set headerlines $v } }

    set problems {}
    lassign [load_baseline] have_base base
    if {!$have_base} {
        lappend problems "BASELINE MISSING: tests/headless/issue_stamp_baseline.txt does not exist -- without it every unstamped file would read as a new violation, so the gate refuses to run rather than emit 1047 false reds"
        return $problems
    }

    set stamped {}          ;# num -> fields
    set files [issue_files]

    foreach {num fname} $files {
        set path [file join $issues_dir $fname]
        if {[catch {read_file $path} text]} {
            lappend problems "$num: unreadable ($text)"
            continue
        }
        set fs [find_stamp $text]
        set n [dict get $fs n]
        if {$n == 0} {
            ## Unstamped.  Grandfathered by NAME, or it is a violation.
            if {![dict exists $base $num]} {
                lappend problems "$num ($fname): a NEW issue file with no **STAMP:** line. Every issue filed after the convention landed must carry one -- see doc/claude/specs/issue_stamp.md. The unconverted set may shrink, never grow."
            }
            continue
        }
        if {$n > 1} {
            lappend problems "$num: $n STAMP lines; exactly one is allowed (the stamp is the file's single newest word -- two of them is the 510-both-words defect in miniature)"
            continue
        }
        set lineno [dict get $fs lineno]
        if {$lineno > $headerlines} {
            lappend problems "$num: the STAMP is at line $lineno; it must be in the first $headerlines lines, where a reader sees it before the prose"
            continue
        }
        set p [parse_stamp [dict get $fs line]]
        if {![dict get $p ok]} {
            lappend problems "$num: malformed stamp -- [dict get $p err]"
            continue
        }
        set f [dict get $p f]
        if {![rev_exists [dict get $f tree]]} {
            lappend problems "$num: tree=[dict get $f tree] does not resolve to a commit in this repo. The whole value of the stamp is that `git show [dict get $f tree]:<file>` recovers every coordinate in the file; a revision that does not resolve recovers nothing."
            continue
        }
        dict set stamped $num $f

        ## --- checks that apply only to stamped files (forward enforcement) ---
        foreach blk [find_blocks $text] {
            set a [dict get $blk attrs]
            set ln [dict get $blk lineno]
            if {[dict exists $a quote]} {
                if {![dict exists $a path]} {
                    lappend problems "$num:$ln: a quote= block must also carry path="
                    continue
                }
                lassign [quote_holds [dict get $a quote] [dict get $a path] [dict get $blk body]] ok why
                if {!$ok} {
                    lappend problems "$num:$ln: $why -- a quoted block that no longer matches its source still LOOKS like valid code, and is the direct on-ramp to a fix that damages working code"
                }
            }
            if {[dict exists $a assert]} {
                set kind [dict get $a assert]
                if {![dict exists $a pat] || ![dict exists $a path] || ![dict exists $a state]} {
                    lappend problems "$num:$ln: an assert= block needs pat=, path= and state=holds|broken"
                    continue
                }
                lassign [assert_eval $kind [dict get $a pat] [dict get $a path]] holds hits why
                if {$holds == -1} {
                    lappend problems "$num:$ln: assertion could not be evaluated -- $why"
                    continue
                }
                set state [dict get $a state]
                if {$state eq "holds" && !$holds} {
                    lappend problems "$num:$ln: the file states this assertion HOLDS and it does not ($hits hits for [dict get $a pat] under [dict get $a path])"
                } elseif {$state eq "broken" && $holds} {
                    ## ⚠ THIS IS THE STALE-FIXED DETECTOR, AND IT IS THE WHOLE
                    ## POINT.  7 of 40 sampled files reported finished work as
                    ## outstanding.  An issue that declares its defect mechanically
                    ## -- "this predicate is false today" -- gets flagged the DAY
                    ## someone makes it true, by the checker, without anyone
                    ## remembering the issue exists.  Nothing closes an issue in
                    ## this project; this closes the greppable ones.
                    lappend problems "$num:$ln: the file states this assertion is BROKEN, but it now HOLDS -- the defect appears FIXED and the issue was never closed. Re-read it and update the stamp."
                } elseif {$state ni {holds broken}} {
                    lappend problems "$num:$ln: state=$state must be holds or broken"
                }
            }
        }
    }

    ## --- cross-file coherence, between stamped files only ---
    ##
    ## A hand-maintained mirror of another file's status is wrong by
    ## construction.  That sentence is not mine: it is issue 0442's own header,
    ## written about mirroring another MODULE's rules, and it applies verbatim to
    ## prose.  0071 is the proof -- its child tables restate six children's
    ## statuses and four of them had drifted.
    foreach {num f} $stamped {
        if {![dict exists $f super]} { continue }
        set s [dict get $f super]
        if {[dict exists $stamped $s]} {
            set sf [dict get $stamped $s]
            if {[dict get $f claim] eq "open" && [dict get $sf claim] eq "open"} {
                lappend problems "$num: claims super=$s replaced it, but $s is itself stamped claim=open"
            }
        }
    }
    return $problems
}

## ---------------------------------------------------------------------------
## THE SELF-TEST -- run before any verdict, per the rule five driver errors bought
## ---------------------------------------------------------------------------
##
## "Every mechanical check is run first against a case whose answer is already
## known, and reports nothing if it fails that."  There are zero stamped files
## in the corpus today, so without this the gate would exercise no parser at all
## and print a green.  These fixtures are the difference between "checked" and
## "found nothing to check".

proc istamp::selftest {} {
    set bad {}
    ## Known-GOOD stamps: must parse.
    set good {
        {**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=3`}
        {**STAMP:** `v1 claim=fixed tree=8608c7ef stamped=2026-09-17 fix=taken open=0`}
        {**STAMP:** `v1 claim=partial tree=aa0e2213 stamped=2026-09-17 fix=partial open=1 by=A3`}
        {**STAMP:** `v1 claim=duplicate tree=fadb226d stamped=2026-09-17 fix=none open=0 super=1397`}
        {**STAMP:** `v1 claim=latent tree=43b40f04 stamped=2026-09-17 fix=untried open=2`}
    }
    foreach g $good {
        set p [parse_stamp $g]
        if {![dict get $p ok]} { lappend bad "GOOD stamp rejected: [dict get $p err] -- $g" }
    }
    ## Known-BAD stamps: each must be REJECTED, and each is a real failure mode.
    set badcases {
        {**STAMP:** `claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=3`}
            {no version token}
        {**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none`}
            {missing open=}
        {**STAMP:** `v1 claim=maybe tree=d64686a1 stamped=2026-09-17 fix=none open=0`}
            {claim outside the vocabulary}
        {**STAMP:** `v1 claim=open tree=16091816 stamped=2026-09-17 fix=none open=0`}
            {a decimal that is not a SHA -- this is driver error 5, a MemTotal in kB read as a revision}
        {**STAMP:** `v1 claim=open tree=d64686a1 stamped=17-09-2026 fix=none open=0`}
            {date not ISO}
        {**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=superseded open=0`}
            {fix=superseded without super= -- the 0442 rule}
        {**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=0 clam=x`}
            {a typo'd key must not be silently ignored}
        {**STAMP:** `v1 claim=open claim=fixed tree=d64686a1 stamped=2026-09-17 fix=none open=0`}
            {duplicate key}
        {**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=-1`}
            {negative outstanding count}
        {Status: OPEN -- measured 2026-08-22}
            {an ordinary prose status line is not a stamp}
    }
    foreach {line why} $badcases {
        set p [parse_stamp $line]
        if {[dict get $p ok]} { lappend bad "BAD stamp accepted ($why): $line" }
    }
    ## The formatter and the parser must agree.
    set rt [format_stamp [dict create claim open tree d64686a1 stamped 2026-09-17 fix none open 3]]
    set p [parse_stamp $rt]
    if {![dict get $p ok]} { lappend bad "round-trip failed: $rt -- [dict get $p err]" }
    return $bad
}

## ---------------------------------------------------------------------------
## REPORT MODE -- advisory, never a verdict
## ---------------------------------------------------------------------------
##
## SCOPE, DECIDED DELIBERATELY AND STATED HERE BECAUSE IT WAS A REAL CHOICE.
## The rot has escaped the tracker into shipped source: src/ciw.tcl repeats
## issue 0654's three dead coordinates AS FACT, and src/ase.tcl cites
## "ase.tcl:802" from inside ase.tcl (line 802 is unrelated).  Corrections land
## outside the issue file more often than in it -- 1436's refutation lives in
## test_ase_dialogs.tcl, 1395's in src/ase_window.tcl, and 1439's "Fixes issue
## 1438" never propagated back to 1438.  A checker confined to doc/claude/issues/
## is blind to two corrections in three.
##
## So this file SCANS source and tests, and GATES only what carries a stamp.
## It cannot gate source citations: there are 937 file:line citations across 27
## src/ files and 1189 in tests/, they are green-field rot, and reddening them on
## day one would either redden T1 permanently or -- far likelier -- get this
## checker quietly disabled, which is precisely how the cleanup rots.  Report,
## do not gate.  The report is D1's work list.

proc istamp::report {} {
    variable repo
    variable issues_dir
    variable t_grep
    set files [issue_files]
    set n 0; set nst 0
    foreach {num fname} $files {
        incr n
        set text [read_file [file join $issues_dir $fname]]
        if {[dict get [find_stamp $text] n] > 0} { incr nst }
    }
    puts "issue files                  : $n"
    puts "carrying a **STAMP:** line   : $nst"
    puts "grandfathered (baseline)     : [dict size [lindex [load_baseline] 1]]"
    foreach {label path} [list "doc/claude/issues" doc/claude/issues \
                               "src"               src \
                               "tests"             tests] {
        set c 0
        if {![catch {exec timeout $t_grep /usr/bin/grep -rnoE {[A-Za-z0-9_./-]+\.(c|h|tcl|sh|py|md)[:][0-9]+} [file join $repo $path]} out]} {
            set c [llength [split [string trim $out] \n]]
        }
        puts [format "coordinate citations in %-20s: %s" $label $c]
    }
}

## ---------------------------------------------------------------------------
## CLI
## ---------------------------------------------------------------------------

proc istamp::main {argv} {
    init
    set cmd [expr {[llength $argv] ? [lindex $argv 0] : "gate"}]
    switch -- $cmd {
        selftest {
            set bad [selftest]
            if {[llength $bad]} {
                puts "SELF-TEST FAILED:"
                foreach b $bad { puts "  $b" }
                return 1
            }
            puts "self-test PASSED"
            return 0
        }
        report {
            report
            return 0
        }
        gate {
            ## Optional corpus override, so a RED can be reproduced against a
            ## throw-away corpus without writing anything into doc/claude/issues/:
            ##     issue_stamp.tcl gate <issuesdir> <baselinefile>
            variable issues_dir
            variable baseline
            if {[llength $argv] >= 2} { set issues_dir [file normalize [lindex $argv 1]] }
            if {[llength $argv] >= 3} { set baseline   [file normalize [lindex $argv 2]] }
            set bad [selftest]
            if {[llength $bad]} {
                puts "!! SELF-TEST FAILED -- no verdict reported."
                foreach b $bad { puts "  $b" }
                return 1
            }
            puts "self-test PASSED ([llength [selftest_case_names]] parser cases)"
            set problems [gate]
            if {[llength $problems] == 0} {
                puts "ISSUE-STAMP: ok (0 problems)"
                return 0
            }
            foreach p $problems { puts "ISSUE-STAMP: $p" }
            puts "ISSUE-STAMP: [llength $problems] problem(s)"
            return 1
        }
        default {
            puts "usage: issue_stamp.tcl gate|report|selftest"
            return 2
        }
    }
}

proc istamp::selftest_case_names {} {
    ## 5 good + 10 bad + 1 round-trip
    return [lrepeat 16 x]
}

if {![info exists ::ISSUE_STAMP_LIB]} {
    exit [istamp::main $argv]
}
istamp::init
