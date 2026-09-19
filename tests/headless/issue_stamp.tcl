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
## file does not pretend otherwise.  Nor is DELIBERATE DISGUISE caught -- a stamp
## or an assertion hidden on purpose behind an invisible character, in HTML with
## attributes, or in a table, a link or a task list: this is a hygiene tool
## against honest error, not a gate against its own authors, and whoever can
## write the file can leave the stamp out (outsider-fixes DECISIONS D18).  An
## HONEST near-miss -- an indented or ~~~ fence, `__STAMP:__` -- is named.  And
## a checkout whose own PATH is not valid UTF-8 is unsupported, and falsely red
## in both locales: under C.UTF-8 the path does not round-trip through Tcl, and
## under LANG=C this box's `timeout` (uutils 0.8.0) refuses a non-UTF-8 argv, so
## every git call fails (MEASURED by S1-fix6's refuter; recorded, not fixed, by
## D19 -- spec section 6).
##
## GREEN BY CONSTRUCTION ON THE DAY IT LANDED, AND STILL ABLE TO GO RED.
## Enforcement is FORWARD ONLY.  A file that carries a stamp is validated against
## the grammar; a file that does not is grandfathered BY ITS EXACT FILE NAME in
## issue_stamp_baseline.txt.  A NEW issue file whose name is not in that
## baseline and which carries no stamp is a FAIL.  The unconverted set can
## therefore shrink but never grow, and nothing is red on day one.
##
## ⚠ THE BASELINE IS A LIST OF FILE NAMES -- NOT A COUNT, AND NOT NUMBERS EITHER.
## A count-based non-regression gate passes when one grandfathered file is
## deleted and one unstamped file is added.  This is the harness batch's W12b
## lesson -- a shared namespace cannot be scored by counting, only by identity --
## and this batch reproduced it twice more (a `pgrep -af` that matches itself; a
## `grep -lieE` that swallowed its own pattern and "measured" 1050 files out of
## 1047).  Match by identity.  Always.  ⚠ AND A NUMBER IS NOT AN IDENTITY HERE
## (outsider-fixes DECISIONS D19): this project's clones mint colliding numbers
## (CLAUDE.md records 1349-1353 naming two defects each), and while the baseline
## listed numbers, a NEW unstamped file under a grandfathered number inherited
## the exemption -- MEASURED by S1-fix6's refuter and red-first by S1-fix7:
## `1349-a-second-defect-under-a-colliding-number.md`, no stamp, `ok (0
## problems)` on every arm.  A name that LOOKS like an issue file and misses the
## canonical `NNNN-<slug>.md` (`1601_x.md`, `1601.md`, `1601-x.MD`) is named too:
## the gate would otherwise never read it at all.
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
## It needs no xschem, no display, no simulator and no T1 run: it reads files IN
## TCL and asks git about REVISIONS, and nothing else.  ⚠ NO exec HERE CARRIES A
## WORD TAKEN FROM AN ISSUE FILE, except a revision that has passed rev_token and
## sits behind --end-of-options (outsider-fixes DECISIONS D16): assert= is
## evaluated by reading the files in Tcl, and a quote= block's `<rev>:<path>`
## reaches git on STDIN, never on its command line -- see assert_eval and
## quote_holds for what an exec of corpus text was MEASURED doing.  Since D19
## the ONLY program this file ever runs is git (report's census is a Tcl scan
## too), and every git call runs with GIT_NO_LAZY_FETCH=1, so no text in an
## issue file can make a partial clone fetch over its remote (git_env).  Revisions
## are asked only where this tree has
## history to answer from: in a shallow clone whose HEAD history is cut (for
## what lies beyond the cut), a no-.git export and a `git init` with nothing
## committed, those are reported NOT VERIFIED by name and every other check
## still runs.  A history that HAS commits gets no exemption at all, and a
## revision must be in HEAD's history, not merely in the store -- see HISTORY
## below.  It runs under plain tclsh AND under
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

    ## Timeouts, seconds: git; the budget of ONE assert= scan, which is Tcl and
    ## therefore cannot be bounded by `timeout` -- assert_scan checks its own
    ## clock instead; and the budget of ALL the assert= scans of one gate() run
    ## together (and of one report's census), because a per-scan bound does not
    ## bound how many scans a corpus asks for.
    ## ⚠ THE TOTAL IS NOT DECORATION (outsider-fixes DECISIONS D19).  With only
    ## the per-scan bound, S1-fix6's refuter appended 100 two-line fences
    ## `assert=absent pat=ZQXNOPE<i> path=. state=holds` -- 5.8 KB of corpus
    ## text -- to stamped 1219, and the CLI gate took 211 s (MEASURED; 10 blocks
    ## 21.5 s): a busy Tcl loop neither `timeout` nor the in-suite watchdog can
    ## interrupt, and about 430 such blocks would have run T1's 900 s per-case
    ## cap out.  Now the run's scans share one clock, and a block reached after
    ## it has run out is a NAMED problem, never evaluated and never passed.  The
    ## real corpus's one block costs ~70 ms of the 60 s.
    variable t_git        30
    variable t_scan       60
    variable t_scan_total 60
    ## The deadline (clock milliseconds) shared by every scan of the gate() run
    ## in progress, or "" outside one.  Set and cleared by gate() alone.
    variable scan_deadline ""

    ## ⚠ THE CALLER'S REPOSITORY-LOCATING VARIABLES, REMOVED FROM EVERY git CALL
    ## THIS CHECKER MAKES (istamp::git_in).  The checker describes the tree it
    ## LIVES IN -- `repo` is derived from its own location -- so the caller's
    ## GIT_DIR, GIT_INDEX_FILE and friends, which name the CALLER's repository,
    ## get no vote.  They are not exotic: git exports GIT_INDEX_FILE (absolute,
    ## pointing at index.lock) and GIT_PREFIX to every pre-commit hook, and
    ## MEASURED 2026-09-18, a GIT_DIR exported to an unrelated repository made
    ## this checker answer for a no-.git export FROM THAT REPOSITORY'S HISTORY --
    ## `history: full`, ten false reds -- which is "an export unpacked inside
    ## another repository" arriving by another route.  The list is git's own
    ## `git rev-parse --local-env-vars` (2.53) MINUS its three config variables,
    ## plus GIT_NAMESPACE.  Config is KEPT on purpose: it names no repository,
    ## and command-scope config (GIT_CONFIG_COUNT/KEY/VALUE) is exactly how the
    ## test drivers hand every suite `safe.directory` for a checkout owned by
    ## another uid (outsider-fixes DECISIONS D7).  Scrubbing it would turn that
    ## container-CI shape `unreadable` again.
    variable git_scrub {
        GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
        GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_IMPLICIT_WORK_TREE
        GIT_GRAFT_FILE GIT_NO_REPLACE_OBJECTS GIT_REPLACE_REF_BASE GIT_PREFIX
        GIT_SHALLOW_FILE GIT_NAMESPACE
    }
    ## ⚠ AND THE LEGACY GRAFTS FILE IS SWITCHED OFF FOR EVERY CALL, by pointing
    ## GIT_GRAFT_FILE at a path that cannot exist (git says nothing about ENOTDIR).
    ## Every question this checker asks is about the history AS STORED, which is
    ## the history a stranger's clone receives: replace refs are not fetched and
    ## `.git/info/grafts` is never sent.  `--no-replace-objects` turns replace
    ## refs off and does NOT turn a grafts file off (MEASURED, git 2.53).  Left
    ## on, a grafts line could cut HEAD's walk -- a local file deciding a verdict
    ## -- or ADD a parent, making a commit nobody else has read as an ancestor of
    ## HEAD: exactly the stamp that passes here and reds every other clone.
    variable no_grafts /dev/null/istamp-no-grafts

    ## THIS PROJECT'S FIRST COMMIT -- StefanSchippers' upstream "Initial
    ## commit" of 2020-08-08, the one root of every clone of this project
    ## (MEASURED 2026-09-18: `git rev-list --max-parents=0 HEAD` names only it,
    ## and it is an ancestor of all 23 local and remote refs).  ⚠ IT DECIDES
    ## WORDING, NEVER A VERDICT.  When a revision does not resolve in a history
    ## that lacks this commit, the problem says why that is likely and what
    ## cures it; the problem is reported either way.  Two earlier rounds let a
    ## test like this one EXEMPT the history instead, and each failed open --
    ## see HISTORY below.  Row H14 of test_issue_stamp.tcl holds the verdict
    ## identical with and without it.
    variable upstream_root 7fe79fb2bf4230e3e1c52432082ccba804e868fc

    ## How many fixtures the last selftest run exercised.  DERIVED, never
    ## hand-written -- see selftest_case_names.
    variable selftest_n 0

    ## What history this tree has to check a revision against -- set by init()
    ## from history_probe(), a dict
    ## {state full|shallow|unborn|none|unreadable why ... ?roots {sha ...}?}.
    ## See the HISTORY section below for why a revision question is not always
    ## askable, and why neither `full` nor `unreadable` ever skips one.
    variable history {}
    ## What the LAST gate() run could not verify, and how many tree= revisions
    ## it did verify.  gate() still returns only its problems, so every existing
    ## caller is unchanged; a caller that must know what was skipped reads these.
    variable last_skips    {}
    variable last_verified 0
    ## rev_verdict's answers, for ONE gate() run only -- see rev_verdict.
    variable rev_cache     {}
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
    variable history
    if {$rootdir eq ""} {
        # tests/headless/issue_stamp.tcl -> repo root is two levels up from the
        # CHECKER's own directory, captured at source time. Never [info script].
        set repo [file dirname [file dirname $home]]
    } else {
        ## ⚠ THIS ARM READ `[file normalize $repo]` -- the namespace variable,
        ## not the argument -- so `init <dir>` silently re-used whatever repo was
        ## set before and ignored the directory it was handed.  No caller passed
        ## one until the history fixtures, which is why nobody noticed.
        set repo [file normalize $rootdir]
    }
    set issues_dir [file join $repo doc claude issues]
    set baseline   [file join $repo tests headless issue_stamp_baseline.txt]
    set history    [history_probe $repo]
    return $repo
}

## ---------------------------------------------------------------------------
## HISTORY -- is there any to check a revision against?
## ---------------------------------------------------------------------------
##
## A stamp's tree= is checked by asking git whether that revision exists, and
## that question has an honest answer only where the history is PRESENT.  Three
## ordinary ways of getting this tree do not bring it (outsider-experience
## audit, 2026-09-18, findings F21 and F24):
##
##   * a SHALLOW clone -- `git clone --depth 1`, the CI default.  Only the newest
##     commit is present.  MEASURED at 4b9565ad: all ten stamped files reported
##     "tree=61af3692 does not resolve", and 61af3692 is an ancestor of HEAD that
##     the clone simply did not fetch.  Ten false reds about files that are fine.
##   * an EXPORT -- a GitHub Download ZIP, a release tarball, `git archive`.  No
##     .git at all, so every git call fails; the suite's revision came back
##     EMPTY, three rows failed on it and the fourth died mid-file.
##   * either of those unpacked INSIDE some other repository, where git would
##     answer happily -- from the OTHER repository's history.
## And an export put under git by hand -- `git init`, perhaps `git add -A` -- has
## no history at all until something is committed.
##
## So the tree is classified ONCE, and only positive evidence of absence skips:
##
##   full        a .git of its own, and git walks HEAD's ancestry all the way
##               back to its root commit(s) -- with the shallow file
##               DISREGARDED, whatever --is-shallow-repository says (D15: a
##               boundary on another branch cuts nothing of HEAD's; D16: a
##               boundary AT HEAD, written by a no-op `fetch --depth 1`, cuts
##               nothing the store does not hold).  A revision that does not
##               resolve, or that resolves without being an ancestor of HEAD
##               (asked with the shallow file disregarded too), is RED.  No
##               exception.
##   shallow     git answers --is-shallow-repository = true, git CANNOT walk
##               HEAD's history with the shallow file disregarded (a commit it
##               needs is not in the store), AND HEAD's honoured walk ends at a
##               boundary: a root whose STORED object names a parent
##               (history_probe says why both, and why not another test).  A
##               revision that resolves and is reached from HEAD is verified;
##               one that does not resolve, or is not reached above the
##               boundary, is NOT VERIFIED -- it may lie beyond the clone's
##               depth -- and is named, never passed.  But an object that IS in
##               the store and is not a commit (a blob, a tree) is RED here as
##               everywhere: that is evidence of a defect, not of depth (D16).
##   unborn      a .git of its own with NO history at all -- `git init`, with or
##               without `git add`.  Three pieces of evidence, all required: HEAD
##               names nothing (git's quiet exit 1), there is not one ref, and
##               there is not one commit object in the store.  Treated exactly
##               as `none`: git is not asked about a revision, because there is
##               no commit for one to be.
##   none        nothing called .git at this tree's root (lstat: a .git that
##               is a link to nowhere is NOT absent).  git is NEVER asked, so a
##               repository above an unpacked export cannot answer for it.
##   unreadable  a .git is here and git cannot read it: git missing or timed
##               out, a broken .git or one that leads nowhere (a dangling link,
##               a gitfile naming a missing directory), a missing or corrupt
##               commit ANYWHERE in
##               HEAD's ancestry, HEAD naming nothing in a repository that does
##               hold refs or commits, or git resolving this tree inside ANOTHER
##               repo.  NOT a skip: it behaves exactly as `full`, so every
##               revision question goes RED.  History that ought to be here and
##               cannot be read is a defect to see, not a gap to excuse.
##
## ⚠ A HISTORY THAT HAS COMMITS GETS NO EXEMPTION -- NONE, WHATEVER ITS DATES OR
## ITS ANCESTRY LOOK LIKE (outsider-fixes DECISIONS D14).  A download put under
## git and COMMITTED is a real, readable history that does not hold this
## project's revisions, and every stamp in it is RED.  That is on purpose, and
## it was not the first answer.  TWO ROUNDS TRIED TO KEEP THAT SHAPE GREEN AND
## EACH ONE OPENED A FAIL-OPEN IN THE STATE THAT MUST BE STRICT:
##   * S1-fix skipped every revision of a history that lacked this project's
##     first commit (a state called `foreign`).  Its refuter MEASURED a history
##     rewritten from its root -- every SHA changed, every date kept -- going
##     GREEN verifying nothing, and a shallow clone with its `shallow` file
##     deleted doing the same.
##   * S1-fix2 skipped a revision stamped before the history's earliest root
##     commit was authored.  The stamp's own, unvalidated `stamped=` date thereby
##     became the evidence that exempted it: its refuter MEASURED a one-digit
##     typo (`stamped=2016-09-17` for 2026) turning a bogus `tree=deadbee0` GREEN
##     in an ordinary full clone -- this project's own state -- and `0000-00-00`
##     doing the same.  A graft (`git replace --graft HEAD`), an orphan branch
##     committed today and a rewrite that moved only the root's author date all
##     failed open the same way.
## A convenience that has to be defended from its own evidence is not worth the
## state it weakens.  Fail-closed beats convenient: a re-initialised download is
## RED, and the red SAYS WHY -- when a revision does not resolve in a history
## that does not contain this project's first commit (`upstream_root`, asked of
## the stored history, `--no-replace-objects`), the problem names the likely
## cause (a download put under git, an orphan squash, a rewrite) and the cure (a
## real clone).  That test changes WORDS ONLY: the problem is reported either
## way, and row H14 holds the verdict identical with it and without it.
##
## ⚠ AND A GIT WARNING IS NOT A FAILURE.  Tcl's `exec` raises on ANY output to
## stderr, so a deprecated setting in the tester's own config
## (`core.fsyncObjectFiles`, MEASURED by S1-fix2's refuter) turned a pristine
## full clone `unreadable`: ten false "does not resolve", fourteen red rows.
## Every git call here is judged by its EXIT CODE alone (git_run); git's words
## are fetched only to explain a failure.  Row H15 plants a warning on purpose.
##
## ⚠ GIT_DIR DOES NOT CHANGE ANY OF THIS -- DECIDED, not overlooked.  This probe
## used to go on asking git when there was no .git but GIT_DIR was set, while
## the table above said `none` never asks: the code and its own header
## disagreed.  The header is right.  GIT_DIR is the CALLER's statement about the
## CALLER's repository, and a hook or a shell exports it for reasons that have
## nothing to do with this tree -- honouring it made a no-.git export answer from
## whatever repository the caller named (MEASURED: `history: full`, 10 false
## reds).  So `none` means exactly "no .git here", and every git call goes
## through git_in, which removes GIT_DIR and the rest of `git_scrub`.  The cost,
## stated: a tree whose ONLY link to its history is GIT_DIR (a bare repository
## checked out with --work-tree) is `none`, and its revision questions skip by
## name.  That is a named skip in a vanishingly rare layout, against a false red
## -- or a write into the wrong repository -- in an ordinary one.
##
## ⚠ THE FAILURE DIRECTION IS "ASK AND GO RED", NEVER "SKIP".  Anything the probe
## cannot positively establish lands in `unreadable`, which skips nothing.  A
## probe that failed OPEN into a skip would be a vacuous green with a reason
## attached -- the family of failure this whole checker was built against.  So a
## failed ancestry walk is never read as "no history": it is `unreadable` unless
## all three pieces of `unborn` evidence hold, and each of them was chosen
## because the broken shapes fail it (MEASURED, git 2.53): a gutted .git whose
## branch still names a lost commit answers HEAD with that commit's name (exit
## 0), and an orphan branch in a repository that has history still has refs.
## Rows H1-H15 of test_issue_stamp.tcl hold every state to that, on fixture
## repositories built for the purpose, whichever shape the suite itself runs in.

## Every git call this checker makes.  `git -C $dir`, under `timeout`, with the
## caller's repository-locating variables (git_scrub) removed for the length of
## the exec and put back exactly as they were.  Errors propagate with their
## -errorcode, so a caller can read git's exit status.
##
## ⚠ JUDGED BY EXIT CODE, NEVER BY STDERR.  git's stderr goes to /dev/null on the
## call itself, so a warning -- a deprecated setting in the tester's config, a
## deprecation hint, GIT_TRACE -- is not a failure (MEASURED: `[core]
## fsyncObjectFiles = true` made every git call here "fail" and a pristine full
## clone read `unreadable`).  Only when the exit code says the call FAILED is it
## run again, stderr kept, for git's own words to put in the reason -- `words`
## 0 skips that for the callers that never print them (rev_exists), which are
## the ones that fail routinely.  A timeout (rc 124) is never re-run.
##
## `envs` is {NAME value ...} set for this one call, AFTER the scrub, so a
## value the caller exported can never stand in for it; every name is put back
## exactly as it was afterwards.  It carries `noshallow` (below) and nothing
## derived from an issue file.
##
## ⚠ AND NO CALL EVER FETCHES: `git_always` rides on EVERY call, after `envs`,
## so no call site can drop it (outsider-fixes DECISIONS D19).  In a partial
## clone -- `clone --filter=blob:none`, which a CI or a large-repo user makes --
## git FETCHES an object it does not hold the moment a command asks for it, from
## the promisor remote, and writes the pack into .git.  GIT_NO_LAZY_FETCH rode
## only on the shallow walk, so S1-fix6's refuter MEASURED, with a blob:none
## clone of a file:// mirror and 0056's tree= set to a blob the clone did not
## hold: `git fetch origin ... --filter=blob:none --stdin`, `git-upload-pack`,
## `index-pack --promisor` and `maintenance run --auto` in GIT_TRACE, 8 -> 12
## files in .git/objects/pack, the blob present afterwards -- and a typo'd full
## SHA did it twice.  Red-first by S1-fix7, and a quote= of an old revision did
## the same through quote_holds.  With an https or ssh remote that is network
## I/O and a transport program, started because of text in an issue file, and
## a write into the repository -- contract A.  git 2.44+ honours the variable;
## an older git ignores it and fetches (INFERRED from git's release notes).
namespace eval istamp { variable git_always {GIT_NO_LAZY_FETCH 1} }
proc istamp::git_env {envs words dir args} {
    variable t_git
    variable git_scrub
    variable no_grafts
    variable git_always
    set envs [dict merge $envs $git_always]
    set names [lsort -unique [concat $git_scrub [dict keys $envs]]]
    set saved {}
    foreach v $names {
        if {[info exists ::env($v)]} {
            lappend saved $v $::env($v)
            unset ::env($v)
        }
    }
    set ::env(GIT_GRAFT_FILE) $no_grafts
    foreach {v val} $envs { set ::env($v) $val }
    set rc [catch {exec timeout $t_git git -C $dir {*}$args 2>/dev/null} out opt]
    if {$rc} {
        set ec [dict get $opt -errorcode]
        if {[lindex $ec 0] eq "CHILDSTATUS" && [lindex $ec 2] == 124} {
            set out "git timed out after $t_git s: git $args"
        } elseif {$words} {
            catch {exec timeout $t_git git -C $dir {*}$args 2>@1} again
            set out [git_words $again]
        }
    }
    foreach v [concat GIT_GRAFT_FILE [dict keys $envs]] {
        if {[info exists ::env($v)]} { unset ::env($v) }
    }
    foreach {v val} $saved { set ::env($v) $val }
    if {$rc} { return -options $opt $out }
    return $out
}
proc istamp::git_run {words dir args} { git_env {} $words $dir {*}$args }
proc istamp::git_in {dir args} { git_run 1 $dir {*}$args }
proc istamp::git_q  {dir args} { git_run 0 $dir {*}$args }

## ⚠ THE SHALLOW FILE, DISREGARDED -- for the one walk that decides `shallow`,
## and for every ancestry question in a `full` history (outsider-fixes DECISIONS
## D16).  A no-op `git fetch --depth 1` of the checked-out branch, or of an
## ancestor of it, writes HEAD -- or that ancestor -- into .git/shallow while
## every commit stays in the store (MEASURED by S1-fix4's refuter, shapes fdself
## and fdanc: 5819 commits present, HEAD's honoured walk 1 or 7 of them).  Read
## through the shallow file, that history "ends" at HEAD, a planted bogus stamp
## went NOT VERIFIED, and merge-base called every real stamp "not an ancestor".
## So `shallow` means only this: WITH THE SHALLOW FILE DISREGARDED, git cannot
## walk HEAD's history back to a root.
##
## THE SPELLING, CHOSEN BY MEASUREMENT ON git 2.53 (all three disregard it:
## fdself/fdanc then walk to 7fe79fb2, a real --depth 1 or --depth 20 clone
## fails with rc 128 "Failed to traverse parents"):
##   * GIT_SHALLOW_FILE set to the EMPTY string -- CHOSEN.  The empty path is
##     git's own "no shallow file" indicator (fetch-pack passes it, and
##     is_repository_shallow tests `!*path` before it opens anything), so git
##     must go on honouring it.  If a future git ignored the variable, the walk
##     would read .git/shallow again, a shallow clone would come out `full`, and
##     its stamps would go RED: the failure direction is loud, never a skip.
##   * GIT_SHALLOW_FILE=/dev/null/none -- works today only because git treats an
##     unopenable shallow file as none; a git that ever died on it instead would
##     turn every full history `shallow`: a skip.  Not chosen.
##   * `git --shallow-file ""` -- an internal, undocumented option, and its `=`
##     spelling is already a usage error (MEASURED rc 129); a git that dropped it
##     would also fail the walk, which reads as `shallow`.  Not chosen.
## The CALLER cannot steer it: GIT_SHALLOW_FILE is in git_scrub, removed from
## every call, and git_env sets this value after the scrub.  GIT_NO_LAZY_FETCH
## rides along so that a walk past a boundary in a partial clone can never
## fetch history into it (MEASURED: git 2.53 does not today; this keeps it so)
## -- and since D19 it rides on every call anyway (git_always).
namespace eval istamp { variable noshallow {GIT_SHALLOW_FILE "" GIT_NO_LAZY_FETCH 1} }

## git's words for a failure, its first `fatal:` or `error:` line FIRST -- the
## callers quote the first line, and with stderr kept that could otherwise be a
## warning or a GIT_TRACE line instead of the reason.
proc istamp::git_words {text} {
    set lines [split [string trim $text] \n]
    set i 0
    foreach ln $lines {
        if {[regexp {^(fatal|error):} $ln]} {
            return [join [linsert [lreplace $lines $i $i] 0 $ln] \n]
        }
        incr i
    }
    return [string trim $text]
}

proc istamp::history_probe {dir} {
    set dir [file normalize $dir]
    set g [file join $dir .git]
    ## ⚠ lstat, NEVER `file exists`, which FOLLOWS a symbolic link: a .git that
    ## is a link to nowhere read as ABSENT -- `none`, every revision NOT VERIFIED,
    ## and a planted bogus tree= green (MEASURED by S1-fix3's refuter, shape
    ## `dangling`).  Something called .git IS here, so this is a checkout whose
    ## history cannot be reached: `unreadable`, never "no .git".  Only lstat's
    ## own "no such file" is absence; any other failure to look is `unreadable`.
    if {[catch {file lstat $g gst} lerr lopt]} {
        set ec [dict get $lopt -errorcode]
        if {[lindex $ec 0] eq "POSIX" && [lindex $ec 1] in {ENOENT ENOTDIR}} {
            return [dict create state none why "no .git in this tree -- it is an export (a Download ZIP, a git archive or a release tarball), not a checkout, so there is no history to resolve a revision against"]
        }
        return [dict create state unreadable why "cannot look for this tree's .git: [lindex [split $lerr \n] 0]"]
    }
    if {![file exists $g]} {
        set to [expr {[catch {file readlink $g} t] ? "?" : $t}]
        return [dict create state unreadable why "a .git is present but leads nowhere: it is a symbolic link to `$to`, which does not exist"]
    }
    ## Said in words, because the exec's own failure text is the `timeout`
    ## program's complaint about a missing file, which names neither git nor PATH.
    if {[auto_execok git] eq ""} {
        return [dict create state unreadable why "a .git is present but git is not installed (not on PATH), so nothing here can be verified"]
    }
    ## ONE exec for both questions: `timeout` alone costs ~100 ms a call here.
    ## rev-parse prints the prefix line (EMPTY at the top of a work tree) and
    ## then true/false.  A git too old to know the second option echoes it back,
    ## which lands in the last arm below as `unreadable`.
    if {[catch {git_in $dir rev-parse --show-prefix --is-shallow-repository} out]} {
        return [dict create state unreadable why "a .git is present but git cannot read it: [lindex [split $out \n] 0]"]
    }
    set lines [split $out \n]
    set sh  [string trim [lindex $lines end]]
    set pfx [string trim [join [lrange $lines 0 end-1] \n]]
    ## Anything but an empty prefix means the .git here is not the repository
    ## git found, which answers from someone else's history.
    if {$pfx ne ""} {
        return [dict create state unreadable why "a .git is present, but git resolves this tree as `$pfx` inside ANOTHER repository"]
    }
    if {$sh ni {true false}} {
        return [dict create state unreadable why "git answered `$sh` to --is-shallow-repository (git older than 2.15?)"]
    }
    ## HEAD's whole ancestry, walked back to its root commit(s).  The proof that
    ## the history is complete -- a missing or corrupt commit anywhere on the way
    ## fails it (MEASURED: `Could not read <c1>` / `Failed to traverse parents`,
    ## exit 128) -- and the roots, which say whether this is this project's
    ## history at all (lacks_upstream: wording only).  ~0.1 s on 5816 commits.
    ## `--no-replace-objects`: the history as STORED.  A replace ref can hide an
    ## ancestor (MEASURED: `git replace --graft HEAD` made HEAD a root), and a
    ## walk that honoured it would neither see a missing object behind it nor
    ## find the project's first commit in front of it.  The legacy
    ## .git/info/grafts file is NOT turned off by that option (MEASURED), so
    ## git_run switches it off for every call -- see `no_grafts`.  `rev-list`,
    ## the plumbing, and not `log`: log obeys the caller's log.* config, and
    ## git_in keeps config on purpose.
    if {[catch {git_in $dir --no-replace-objects rev-list --max-parents=0 HEAD} roots]} {
        set not_unborn [unborn_evidence $dir]
        if {$not_unborn eq ""} {
            return [dict create state unborn why "a .git with no history at all -- HEAD names nothing and there is not one ref or commit in it (`git init`, nothing committed yet), so no revision can resolve here"]
        }
        return [dict create state unreadable why "git cannot walk this tree's history back to its root commit ([lindex [split $roots \n] 0]), and it is not an empty repository either: $not_unborn"]
    }
    set rl {}
    foreach ln [split [string trim $roots] \n] {
        set ln [string trim $ln]
        if {![regexp {^[0-9a-f]{40}([0-9a-f]{24})?$} $ln]} {
            return [dict create state unreadable why "git answered `$ln` for a root commit"]
        }
        lappend rl $ln
    }
    if {![llength $rl]} {
        return [dict create state unreadable why "git walked HEAD's history and named no root commit"]
    }
    ## ⚠ THE SHALLOW FLAG BELONGS TO THE REPOSITORY; THE QUESTION IS WHETHER THE
    ## STORE CAN ANSWER FOR HEAD (outsider-fixes DECISIONS D15, then D16).  One
    ## `git fetch --depth 1` of ANOTHER branch sets --is-shallow-repository for
    ## good, and so does a stranger's CI flow of `clone --depth 1 -b main` then a
    ## plain fetch of this branch -- while HEAD's own history stays whole
    ## (MEASURED by S1-fix3's refuter, shapes fetchd, selfdepth and ciflow; an
    ## empty `shallow` file did the same).  S1-fix4 answered that with "a root of
    ## HEAD's walk whose stored object names a parent", and its refuter MEASURED
    ## the hole one step further on: a no-op `fetch --depth 1` of THIS branch, or
    ## of an ancestor of it, puts HEAD (or the ancestor) into the shallow file --
    ## a boundary ON HEAD's path -- while all 5819 commits are still in the store.
    ## The walk stopped there, the probe said `shallow`, and a planted bogus
    ## tree= went NOT VERIFIED (shapes fdself, fdanc).
    ##   So the decision is the store's, not the shallow file's: walk HEAD again
    ## WITH THE SHALLOW FILE DISREGARDED (`noshallow`, above).  If that walk
    ## reaches a root, every commit HEAD's history needs is here and the tree is
    ## `full` -- whatever .git/shallow says -- and every later history question
    ## is asked the same way (rev_is_ancestor).  Only if git CANNOT read a commit
    ## that walk needs (exit 128, "Failed to traverse parents") is it `shallow`,
    ## and then a boundary must also sit on HEAD's honoured walk (a root whose
    ## stored object names a parent, shallow_boundaries) -- two pieces of
    ## evidence that must agree, or the tree is `unreadable`.  Asked only when the
    ## flag is up, so a clone that was never shallow pays nothing for it.
    if {$sh eq "true"} {
        variable noshallow
        if {![catch {git_env $noshallow 0 $dir --no-replace-objects rev-list --max-parents=0 HEAD} full_roots fopt]} {
            set frl {}
            foreach ln [split [string trim $full_roots] \n] {
                set ln [string trim $ln]
                if {![regexp {^[0-9a-f]{40}([0-9a-f]{24})?$} $ln]} {
                    return [dict create state unreadable why "git answered `$ln` for a root commit of HEAD's history walked with the shallow file disregarded"]
                }
                lappend frl $ln
            }
            if {![llength $frl]} {
                return [dict create state unreadable why "git walked HEAD's history with the shallow file disregarded and named no root commit"]
            }
            set r8 {}
            foreach r $frl { lappend r8 [string range $r 0 7] }
            return [dict create state full roots $frl noshallow 1 why "a full history: git calls this repository shallow, but the store holds every commit HEAD's history needs -- walked with the shallow file disregarded, it is complete back to its root commit [join $r8 {, }] -- so every stamped revision must resolve"]
        }
        set ec [dict get $fopt -errorcode]
        set code [expr {[lindex $ec 0] eq "CHILDSTATUS" ? [lindex $ec 2] : -1}]
        if {$code != 128} {
            return [dict create state unreadable why "git calls this repository shallow, and its walk of HEAD's history with the shallow file disregarded neither completed nor stopped at a missing commit (exit $code[expr {$code == 124 ? ", timed out" : ""}])"]
        }
        if {[catch {shallow_boundaries $dir $rl} bnd]} {
            return [dict create state unreadable why "git calls this repository shallow and cannot show the root commits of HEAD's history ([lindex [split $bnd \n] 0])"]
        }
        if {![llength $bnd]} {
            return [dict create state unreadable why "git cannot walk HEAD's history with the shallow file disregarded, yet nothing its shallow file names cuts HEAD's walk -- a missing commit that no shallow boundary explains"]
        }
        set b8 {}
        foreach b $bnd { lappend b8 [string range $b 0 7] }
        return [dict create state shallow roots $rl why "a shallow clone: HEAD's history ends at the shallow boundary [join $b8 {, }], and git cannot read what lies beyond it even with the shallow file disregarded, so commits older than that are not in it"]
    }
    return [dict create state full roots $rl why "a full clone: every stamped revision must resolve"]
}

## The roots of HEAD's walk that are SHALLOW BOUNDARIES: those whose STORED
## commit object names a parent.  One exec for all of them (`timeout` costs
## ~100 ms a call).  A root git cannot show is not counted -- the failure
## direction is `full`, which asks and goes red, never a skip.
proc istamp::shallow_boundaries {dir roots} {
    set out [git_in $dir --no-replace-objects cat-file --batch << "[join $roots \n]\n"]
    set b {}
    foreach r $roots {
        ## $r is 40 or 64 hex (history_probe checked it), so it is safe in a pattern.
        if {[regexp -line "^$r commit \[0-9\]+\ntree \[0-9a-f\]+\nparent \[0-9a-f\]+\$" $out]} {
            lappend b $r
        }
    }
    return $b
}

## POSITIVE evidence that a repository has no history at all: "" if it holds,
## else the reason it does not.  Asked only after HEAD's ancestry walk failed,
## so every answer that is not exactly the empty repository's lands the tree in
## `unreadable`.  Each question was chosen because a broken shape fails it
## (MEASURED, git 2.53):
##   HEAD     `rev-parse -q --verify HEAD` exits 1, silently, for an unborn
##            branch.  A gutted .git whose branch still names a lost commit
##            answers 0 and that commit's name -- NOT `HEAD^{commit}`, which
##            exits 1 for both and cannot tell them apart.
##   refs     not one.  An orphan branch checked out in a repository that HAS a
##            history has an unborn HEAD too; its other branches give it away.
##   objects  not one commit in the store, alternates included.  `git add` makes
##            blobs and never a commit.
proc istamp::unborn_evidence {dir} {
    if {![catch {git_in $dir rev-parse -q --verify HEAD} h opt]} {
        return "HEAD names [string range [string trim $h] 0 7], so there is a history and git cannot read it"
    }
    set ec [dict get $opt -errorcode]
    if {[lindex $ec 0] ne "CHILDSTATUS" || [lindex $ec 2] != 1} {
        return "git cannot say what HEAD names: [lindex [split $h \n] 0]"
    }
    if {[catch {git_in $dir for-each-ref --count=1 {--format=%(refname)}} refs]} {
        return "HEAD names nothing, and git cannot list the refs: [lindex [split $refs \n] 0]"
    }
    if {[string trim $refs] ne ""} {
        return "HEAD names nothing, but the repository holds refs ([string trim $refs]) -- an orphan branch in a history that is there"
    }
    if {[catch {git_in $dir cat-file --batch-all-objects {--batch-check=%(objecttype)}} objs]} {
        return "HEAD names nothing, and git cannot list the objects: [lindex [split $objs \n] 0]"
    }
    if {[lsearch -exact [split $objs \n] commit] >= 0} {
        return "HEAD names nothing and there is no ref, but the store holds commits"
    }
    return ""
}

proc istamp::history_state {} {
    variable history
    ## Never probed = nothing established = ask and go red.
    if {![dict exists $history state]} { return unreadable }
    return [dict get $history state]
}

proc istamp::history_why {} {
    variable history
    variable upstream_root
    if {![dict exists $history why]} { return "history was never probed" }
    set why [dict get $history why]
    if {[lacks_upstream]} {
        append why " -- NOTE: HEAD's history does not contain the project's first commit [string range $upstream_root 0 7], so this is not an ordinary clone of the project (a download put under git, an orphan squash or a rewrite?); any stamped revision that does not resolve here is reported, and a real clone is the cure"
    }
    return $why
}

## ⚠ WORDING ONLY -- the ONE place the project's first commit is consulted, and
## nothing that decides a verdict calls it.  1 exactly when this is a full
## history whose stored ancestry (history_probe's roots, --no-replace-objects)
## does not contain `upstream_root`: a download put under git and committed, an
## orphan-branch squash, or a rewritten history.  0 whenever that is not KNOWN
## -- a shallow clone's roots are its depth, and `unreadable` has none.
proc istamp::lacks_upstream {} {
    variable history
    variable upstream_root
    if {[history_state] ne "full" || ![dict exists $history roots]} { return 0 }
    return [expr {[lsearch -exact [dict get $history roots] $upstream_root] < 0}]
}

## The sentence a problem gains when lacks_upstream holds: the likely cause and
## the cure.  "" otherwise.
proc istamp::upstream_note {} {
    variable upstream_root
    if {![lacks_upstream]} { return "" }
    return " HEAD's history does not contain the project's first commit ([string range $upstream_root 0 7]), so this is not an ordinary clone of the project -- most likely a downloaded copy put under git (`git init` and a commit), a squash onto an orphan branch, or a rewritten history.  Run this in a real clone: `git clone <url>`, without --depth."
}

## One revision question, as {verdict why}.  Three verdicts: `ok` (it
## resolves AND is in HEAD's history), `bad` (a finding) or `skip` (there is
## positive evidence that the answer cannot be had here: a shallow clone's
## boundary, or no history at all).  For `skip`, `why` names that evidence and
## the gate carries it into the NOT VERIFIED line; for `bad` it is one of
## `unresolved`, `notancestor`, `noanswer` or `{notcommit <type>}`, and the gate
## words the problem from it.  `none` and `unborn` never reach git at all.
## ⚠ `full` and `unreadable` NEVER skip.  There used to be a per-stamp date
## rule here, and its own evidence was the stamp's unvalidated date -- see
## HISTORY above, and do not put it back.
##
## ⚠ RESOLVING IS NOT ENOUGH: THE REVISION MUST BE AN ANCESTOR OF HEAD
## (outsider-fixes DECISIONS D15).  `cat-file -e` asks the local STORE, and the
## store holds commits no clone will ever carry: one amended or reset away,
## a stash, a branch never pushed.  MEASURED by S1-fix3's refuter (shape
## `amend`): `commit --allow-empty`, `reset --soft HEAD~1`, and a stamp naming
## that commit passed in the author's own clone -- the pre-commit gate, where it
## should be caught -- and the same stamp, committed, turned a fresh clone RED:
## three counted lines in every stranger's T1.  Measured before this rule
## landed: all ten stamps in the real corpus name 61af3692, an ancestor of HEAD.
## In a SHALLOW history the answer holds only down to the boundary, so a
## revision that resolves but is not reached above it is NOT VERIFIED, by name.
##
## Memoised for the length of ONE gate() run (gate resets rev_cache), because
## each question is an `exec timeout git`, and `timeout` alone costs ~100 ms per
## call on this box (measured: `exec timeout 30 true` 104 ms against 0.8 ms bare)
## -- while the real corpus names one revision ten times.  Never across runs:
## the repository under the checker can change between them.
proc istamp::rev_verdict {rev} {
    variable rev_cache
    set st [history_state]
    if {$st eq "none"}   { return [list skip "none: no .git here"] }
    if {$st eq "unborn"} { return [list skip "unborn: no commits yet"] }
    if {![dict exists $rev_cache $rev]} {
        if {![rev_exists $rev]} {
            ## ⚠ "DOES NOT RESOLVE TO A COMMIT" IS TWO ANSWERS, AND ONLY ONE OF
            ## THEM IS ABOUT DEPTH (D16).  `cat-file -e X^{commit}` fails alike
            ## for an object that is not here and for one that IS here and is not
            ## a commit -- and in a shallow clone the second was skipped as
            ## "beyond the depth?" (MEASURED by S1-fix4's refuter: tree= naming
            ## HEAD:README, a blob, NOT VERIFIED in --depth 1, fdself and fdanc).
            ## A blob or a tree in the store is positive evidence of a defect, in
            ## every state.  A tag is not decided here: its commit may lie beyond
            ## the depth.  Asked only on this failure path.
            set ty [rev_type $rev]
            if {$ty in {blob tree}} {
                set v [list bad [list notcommit $ty]]
            } else {
                set v [expr {$st eq "shallow" ? [list skip "shallow: beyond the depth?"] : [list bad unresolved]}]
            }
        } else {
            switch -- [rev_is_ancestor $rev] {
                1       { set v [list ok ""] }
                0       { set v [expr {$st eq "shallow" ? [list skip "shallow: resolves, but is not reached above the shallow boundary"] : [list bad notancestor]}] }
                default { set v [list bad noanswer] }
            }
        }
        dict set rev_cache $rev $v
    }
    return [dict get $rev_cache $rev]
}

## The sentence a `bad` verdict earns, for `what` (`tree=X` or `quote=X`):
## the finding, and then the cause and cure when the history lacks the
## project's first commit (upstream_note -- wording only).
proc istamp::rev_problem {what rev why} {
    switch -- [lindex $why 0] {
        notcommit {
            set s "$what names a [lindex $why 1] in this repository, not a commit, so it does not resolve to a commit in this repo: `git show $rev:<file>` recovers nothing.  A stamp names the commit its file was checked against."
        }
        notancestor {
            set s "$what resolves in this checkout but is NOT in HEAD's history (git merge-base --is-ancestor says no): it is reachable only from something a clone does not carry -- a commit amended or reset away, a stash, a branch never merged -- so `git show $rev:<file>` works here and fails in every other clone.  Stamp a commit on HEAD's history."
        }
        noanswer {
            set s "$what resolves, but git could not say whether it is in HEAD's history, so nothing it names is verified."
        }
        default {
            set s "$what does not resolve to a commit in this repo."
        }
    }
    return "$s[upstream_note]"
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
    if {![rev_token $tree]} {
        return [dict create ok 0 err "tree=$tree is not a revision (7-40 hex, at least one a-f)" f $f]
    }
    if {![regexp {^[0-9]{4}-[0-9]{2}-[0-9]{2}$} [dict get $f stamped]]} {
        return [dict create ok 0 err "stamped=[dict get $f stamped] is not YYYY-MM-DD" f $f]
    }
    ## ⚠ AND IT MUST BE A DAY ON THE CALENDAR.  `0000-00-00` has the right shape
    ## and names no day at all, and while a date rule trusted this field it was
    ## MEASURED exempting a bogus tree= (S1-fix2's refuter).  Nothing reads the
    ## date that way any more, but a field that states a fact must be a fact.
    if {![is_calendar_day [dict get $f stamped]]} {
        return [dict create ok 0 err "stamped=[dict get $f stamped] is not a day on the calendar" f $f]
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
        set ok_super [expr {[regexp {^[0-9]{4}$} $s] || $s eq "self" || [rev_token $s]}]
        if {!$ok_super} {
            return [dict create ok 0 err \
                "super=$s must be a 4-digit issue number, a revision, or `self`" f $f]
        }
    }
    return [dict create ok 1 err "" f $f]
}

## A REVISION TOKEN: 7-40 hex with at least one a-f.  The grammar of tree=,
## super= and quote= alike -- ONE proc, so the three cannot drift apart.
## ⚠ quote= HAD NO GRAMMAR AT ALL, and it is the one of the three that reaches
## git: an issue block `quote=--output=<file> path=x` made quote_holds run
## `git show --output=<file>:x` and WRITE a 21 KB file during validation, in T1,
## over the real corpus (MEASURED by S1-fix3's refuter).  A token that is hex
## cannot begin with `-`, and every git call that carries one also passes
## --end-of-options (rev_exists, rev_is_ancestor, quote_holds): two locks, and
## either alone holds -- row H17 of test_issue_stamp.tcl measures both.
proc istamp::rev_token {s} {
    return [expr {[regexp {^[0-9a-f]{7,40}$} $s] && [regexp {[a-f]} $s]}]
}

## Is $d (YYYY-MM-DD) a real day of the Gregorian calendar, year 0001-9999?
## Plain arithmetic, deliberately not `clock scan`, which rolls 2026-02-30 over
## to March 2 and 2026-13-01 to the next January (MEASURED, Tcl 8.6.17).
proc istamp::is_calendar_day {d} {
    if {![regexp {^([0-9]{4})-([0-9]{2})-([0-9]{2})$} $d -> y m dd]} { return 0 }
    scan $y %d y ; scan $m %d m ; scan $dd %d dd
    if {$y < 1 || $m < 1 || $m > 12 || $dd < 1} { return 0 }
    set dim [lindex {31 28 31 30 31 30 31 31 30 31 30 31} [expr {$m - 1}]]
    if {$m == 2 && $y % 4 == 0 && ($y % 100 != 0 || $y % 400 == 0)} { set dim 29 }
    return [expr {$dd <= $dim}]
}

## Format a field dict back into a stamp line.  Used by `restamp` and by the
## fixtures, so the writer and the reader can never drift apart.
##
## ⚠ THIS LIST IS THE WRITER'S WHOLE VOCABULARY AND IT MUST NOT DRIFT FROM
## `ok_key`, WHICH IS THE READER'S.  It shipped without `scope` -- a key
## `parse_stamp` accepts and `ok_key` contains -- so every round-trip through the
## formatter SILENTLY DELETED the one field that records a defect closed on ONE
## route and live on another.  In this corpus that is exactly one file, 0216, and
## one file is enough: it is the case the field was invented for, and dropping it
## closes a live defect (the STALE-OPEN direction, the dangerous one).
##
## Nothing caught it, because the round-trip fixture carried no scope and asked
## only whether the result PARSED -- and a fixture whose INPUT lacks a field
## cannot detect a formatter that drops it.  That is the vacuous-green family,
## inside the machinery built to treat it, for the second time (after row B1).
## The selftest now round-trips EVERY field and asserts the whole dict, and suite
## row B4 round-trips the REAL corpus, so a key added to `ok_key` and forgotten
## here reddens instead of quietly eating data.
##
## Order follows the spec's field table (issue_stamp.md §2).
proc istamp::format_stamp {f} {
    set out "v1"
    foreach k {claim tree stamped fix open super scope by} {
        if {[dict exists $f $k]} { append out " $k=[dict get $f $k]" }
    }
    return "**STAMP:** `$out`"
}

## Compare two field dicts without caring what order the keys were written in.
## The round-trip fixture asserts the WHOLE dict, and a plain string compare of
## two dicts is really a compare of their key ORDER -- which would redden if
## anyone reordered format_stamp's key list without losing anything at all.
## Canonicalise, so the fixture answers the question it is actually asking:
## did any field go missing or change value?
proc istamp::dict_canon {d} {
    set out {}
    foreach k [lsort [dict keys $d]] { lappend out $k [dict get $d $k] }
    return $out
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
    return [dict get [fence_scan $text] blocks]
}

## find_blocks' parser, which also records where every fence OPENED and whether
## it closed -- so that a fence the file never closes can be named instead of
## vanishing (stray_quotes).  A dict:
##   blocks  the closed blocks that carry attributes (find_blocks' answer)
##   opened  lineno -> 1 if that fence closed, 0 if the file ended inside it
##
## ⚠ FENCES OPEN AND CLOSE THE COMMONMARK WAY (outsider-fixes DECISIONS D16).
## This closed a block on ANY line of three or more backticks, so a quote
## opened with FOUR -- which is how markdown lets a block contain a ``` line --
## ended at its first inner ``` line: only the text above it was verified, the
## fence that "reopened" there carried no quote, and a rotted line below it
## passed `ok (0 problems)` while markdown renders it inside the quote (MEASURED
## by S1-fix4's refuter; the same line in a 3-backtick fence was red).  Now:
##   * a fence is a run of 3+ backticks, or of 3+ tildes, indented at most 3
##     spaces; it closes only on a run of the SAME character, AT LEAST AS LONG,
##     indented at most 3 spaces, with nothing after it but blanks;
##   * a ~~~ fence and an indented fence are fences -- what is inside them is
##     text, not a block -- but only a column-0 backtick fence is READ as one
##     (a quote on any other kind is named by stray_quotes, as before).
## Not modelled, and stated: containers (a fence inside `>` or a list item is
## not seen as one) and a backtick in a backtick fence's info string.  Each can
## only make this parser see a block markdown does not, or miss one it does --
## and a missed quote fence is named by stray_quotes, never passed.
##
## ⚠ A MARKED FENCE'S INFO STRING IS READ IN FULL (outsider-fixes DECISIONS
## D19).  This kept the words shaped `key=value` and silently DROPPED every
## other one, so a block the grammar calls malformed was evaluated as a
## different, weaker claim with no word said.  MEASURED by S1-fix6's refuter
## and red-first by S1-fix7, in stamped 1219 in a full clone: `assert=absent
## pat="static int" path=src state=holds` -- a phrase on 463 lines of src --
## said `ok (0 problems)`, because it searched for the literal `"static` and
## threw `int"` away; `assert=present pat=static nonexistent_zz_symbol ...`
## -- a phrase on NO line -- said ok too, because it searched for `static`.
## The stamp's grammar has always refused a token that is not key=value.  So a
## fence is MARKED when any word of its info string is shaped `key=value`, and
## then its info string must be exactly: at most one leading language word (no
## `=` in it), then `key=value` words only, each key known (`fence_keys`) and
## given once.  Anything else lands in the block's `bad` list, and the gate
## names the block and does not evaluate it (fail-closed: nothing it claims is
## passed).  A fence with no key=value word is an ordinary code sample, and
## its info string is nobody's business (row N2).
namespace eval istamp { variable fence_keys {quote path fix assert pat state} }
proc istamp::fence_info {info} {
    variable fence_keys
    set words {}
    foreach t [split [string trim $info]] { if {$t ne ""} { lappend words $t } }
    set toks {}; set bad {}; set seen {}; set marked 0
    foreach t $words { if {[regexp {^[a-z]+=} $t]} { set marked 1 ; break } }
    if {!$marked} { return [list {} {}] }
    set i 0
    foreach t $words {
        incr i
        if {[regexp {^([a-z]+)=(.*)$} $t -> k v]} {
            if {$k ni $fence_keys} {
                lappend bad "`[string range $t 0 39]` has a key the grammar does not know (known: $fence_keys)"
            } elseif {[dict exists $seen $k]} {
                lappend bad "`[string range $t 0 39]` gives `$k=` a second time"
            } else {
                dict set seen $k 1
                lappend toks $k $v
            }
        } elseif {$i == 1 && [string first = $t] < 0} {
            ## the language word
        } else {
            lappend bad "`[string range $t 0 39]` is not a key=value word"
        }
    }
    return [list $toks $bad]
}
proc istamp::fence_scan {text} {
    set out {}
    set opened {}
    set i 0
    set in 0
    set fch ""
    set flen 0
    set readable 0
    set attrs {}
    set fbad {}
    set body {}
    set startno 0
    foreach ln [split $text \n] {
        incr i
        if {!$in} {
            if {[regexp {^( {0,3})(`{3,}|~{3,})(.*)$} $ln -> ind fence info]} {
                set fch  [string index $fence 0]
                set flen [string length $fence]
                set readable [expr {$ind eq "" && $fch eq "`"}]
                set toks {}; set bad {}
                if {$readable} { lassign [fence_info $info] toks bad }
                set in 1; set attrs $toks; set fbad $bad; set body {}; set startno $i
                dict set opened $i 0
            }
        } else {
            if {[regexp {^ {0,3}(`{3,}|~{3,})[ \t]*$} $ln -> cf]
                && [string index $cf 0] eq $fch && [string length $cf] >= $flen} {
                set in 0
                dict set opened $startno 1
                if {$readable && ([llength $attrs] || [llength $fbad])} {
                    lappend out [dict create attrs $attrs body [join $body \n] lineno $startno bad $fbad]
                }
            } else {
                lappend body $ln
            }
        }
    }
    return [dict create blocks $out opened $opened]
}

## ---------------------------------------------------------------------------
## TEXT THE PARSER DOES NOT READ -- named, never a silent pass
## ---------------------------------------------------------------------------
##
## ⚠ THE PARSER READS EXACTLY TWO SHAPES: a `**STAMP:**` line at column 0, and
## a CLOSED ``` fence at column 0.  Anything written to be one of those and
## missing by a character used to vanish: S1-fix3's refuter MEASURED a rotted
## quote= passing `ok (0 problems)` in an indented fence (two spaces, which
## CommonMark renders as a code block), in a ~~~ fence, and in a fence the file
## never closed -- while the same block at column 0 was red.  The reader sees a
## quote that looks checked; nothing checked it.  So every such line is a
## problem, by line number and cause (outsider-fixes DECISIONS D15).
##
## What counts is deliberately NARROW, because on a 1050-file corpus an
## over-firing check gets disabled: a stamp-SHAPED line (the stamp word and a
## colon, in any emphasis or followed by the stamp's own `v1 body, starting the
## line once markdown's containers are stripped -- stamp_shaped), and a FENCE
## line carrying a quote= or (since D18) an assert= attribute.  A `quote=` in prose or inside
## code -- 0993 has `quote=!quote;`, C in backticks -- is not an attribute and
## is not touched, and neither is a stamp MENTIONED mid-sentence (row S16).
## MEASURED 2026-09-18 at caa110ba, all 1050 issue files: zero lines of either
## kind (84 indented fences, none carrying quote=; 0 ~~~ fences; the 7 bold
## "stamp" lines are prose, "**Stamp the record** with a token").

## A line's content once markdown's containers are stripped: indentation,
## blockquote markers, list markers and heading hashes.
##
## ⚠ ONE PASS, NEVER A LOOP THAT COPIES THE LINE (outsider-fixes DECISIONS D18).
## This stripped one container per `regexp`, and each call copied the rest of
## the line into a capture, so a line of N markers cost N copies of up to N
## characters.  MEASURED by S1-fix5's refuter: 40k `>` took 4 s, 40k `- ` 8.5 s,
## and three lines of 50k `>` in one grandfathered file took the gate from
## 0.6 s to 19.2 s -- a busy Tcl loop, which neither `timeout` (it wraps an
## exec, not Tcl) nor the in-suite watchdog (W13: a timer fires only at the
## event loop) can interrupt, driven by nothing but corpus text.  Now the whole
## run of containers is ONE match with no capture, and the rest is ONE
## `string range`: 1 MB of `>` in ~5 ms (MEASURED, Tcl 8.6.17).  The same
## answer as the loop, because every container token is prefix-closed (a `#`
## run or a digit run must be taken whole, and a blank run split anywhere
## strips the same): MEASURED identical on 200 000 random strings over these
## characters.  Row Q12 holds the cost.
proc istamp::md_strip {ln} {
    regexp {^(?:[ \t]+|>|#+[ \t]+|[-*+][ \t]+|[0-9]+[.)][ \t]+)*} $ln pre
    return [string range $ln [string length $pre] end]
}

## Why a line whose content is a stamp or a fence is not read where it sits.
proc istamp::stray_cause {raw} {
    if {[regexp {^[ \t]} $raw]}                  { return "indented" }
    if {[regexp {^>} $raw]}                      { return "inside a blockquote" }
    if {[regexp {^#} $raw]}                      { return "inside a heading" }
    if {[regexp {^([-*+]|[0-9]+[.)])[ \t]} $raw]} { return "inside a list item" }
    return ""
}

## Is this line's content (containers already stripped) a stamp written some
## other way than the one the parser reads?  ⚠ BY CONTENT, NOT BY ONE SPELLING
## (outsider-fixes DECISIONS D16).  This matched only `**`, and markdown has
## other spellings of bold that render IDENTICALLY: `__STAMP:__`,
## `<strong>STAMP:</strong>` and `<b>STAMP:</b>` each carried a bogus tree= in a
## grandfathered file past `ok (0 problems)` (MEASURED by S1-fix4's refuter;
## markdown-it renders them to the same HTML as `**STAMP:**`).  So emphasis
## markup is taken off first -- `*` and `_` runs, and <strong> <b> <em> <i> tags
## -- and then the line is stamp-shaped when it begins with the word STAMP and a
## colon and
##   * it was written in emphasis of ANY kind (the rule this had, for `**`, now
##     for all of them: a bold "Stamp:" at the head of a line is a stamp attempt,
##     whatever follows), or
##   * the stamp's own body follows: `v1, with or without its backtick (so
##     plain `STAMP: `v1 ...`` counts too).
## Still anchored at the head of the content: a stamp MENTIONED mid-sentence
## (row S16) is prose, and `**Stamp the record**` has no colon after the word.
proc istamp::stamp_shaped {c} {
    set bare [regsub -all -nocase {</?(strong|b|em|i)[ \t]*>} $c ""]
    set bare [regsub -all {\*+|_+} $bare ""]
    if {![regexp -nocase {^[ \t]*stamp[ \t]*:} $bare]} { return 0 }
    if {[regexp -nocase {^(\*|_|<(strong|b|em|i)[ \t]*>)} $c]} { return 1 }
    return [regexp -nocase {^[ \t]*stamp[ \t]*:[ \t]*`?[ \t]*v1(?:[ \t`]|$)} $bare]
}

## Stamp-shaped lines find_stamp does not read.  One problem each.
##
## ⚠ AND A LINE CARRYING A STAMP'S BODY IS NAMED WHATEVER PRECEDES IT
## (outsider-fixes DECISIONS D19).  stamp_shaped needs the word STAMP followed
## by a COLON, so a stamp that lost its colon was prose: MEASURED by S1-fix6's
## refuter and red-first by S1-fix7, `**STAMP** `v1 claim=fixed tree=deadbee0
## ...`` as line 3 of grandfathered 0057 said `ok (0 problems)`, and so did
## `STAMP `v1 ...``, `**Stamp** `v1 ...``, `**STAMP -**`, `**STAMP;**` and
## `**STAMP.**` -- one-character typos of the canonical line, whose bogus tree=
## nothing ever checked.  The body itself -- a backtick, `v1`, then `claim=` --
## is what nobody writes by accident, so any line holding it that find_stamp
## does not read is a problem, wherever it sits.  MEASURED 2026-09-18 at
## aa5cece0, all 1047 numbered issue files: the only lines holding it are the
## ten real stamps, so the real corpus gains nothing.
proc istamp::stray_stamps {num text} {
    set out {}
    set words [regexp -nocase {stamp} $text]
    set bodies [regexp {`v1[ \t]+claim=} $text]
    if {!$words && !$bodies} { return $out }
    set i 0
    foreach ln [split $text \n] {
        incr i
        if {[regexp {^\*\*STAMP:\*\*} $ln]} { continue }
        if {$words && [regexp -nocase {stamp} $ln] && [stamp_shaped [md_strip $ln]]} {
            set cause [stray_cause $ln]
            if {$cause eq ""} { set cause "not spelled exactly `**STAMP:**`" }
            lappend out "$num:$i: a **STAMP:** line the parser does not read ($cause) -- a stamp is read only at column 0 and spelled exactly `**STAMP:**`, so nothing this one states is checked"
            continue
        }
        if {$bodies && [regexp -indices {`v1[ \t]+claim=} $ln at]} {
            set head [string trim [string range $ln 0 [expr {[lindex $at 0] - 1}]]]
            set shown [expr {$head eq "" ? "nothing" : "`[string range $head 0 39][expr {[string length $head] > 40 ? "..." : ""}]`"}]
            lappend out "$num:$i: a line carrying a stamp's body (`v1 claim=...) that is not a **STAMP:** line the parser reads (it is preceded by $shown) -- a stamp is read only at column 0 and spelled exactly `**STAMP:** `, so nothing this one states is checked"
        }
    }
    return $out
}

## Fence lines carrying a `quote=` or an `assert=` attribute that no block the
## gate READS came from.  `scan` is fence_scan's answer for a STAMPED file, or
## "" for a file with no stamp, where no marked block is ever read.  One problem
## per attribute per line.  `keys` narrows it (stray_quotes asks for quote=
## alone); the keys are this file's own literals, never corpus text.
##
## ⚠ assert= GETS THE SAME TREATMENT quote= HAS HAD SINCE D15 (outsider-fixes
## DECISIONS D18).  Only quote= was named here, so a FALSE assertion -- `pat=
## SABOTAGE path=src state=holds`, eight real hits -- went `ok (0 problems)` in a
## ~~~ fence, an indented fence, a blockquote, a list item, a fence never closed
## and a grandfathered file (MEASURED by S1-fix5's refuter, and again red-first
## by S1-fix6 with one more: a fence inside another block), while the same
## block at column 0 was RED.  A reader sees a claim about the tree that looks
## checked, and nothing evaluated it.  MEASURED at 9fbc6fd9, all 1047 numbered
## issue files: one line anywhere carries `assert=`, it is 1219:72's column-0
## fence in a stamped file, it is read, and the real corpus gains no problem.
proc istamp::stray_attrs {num text scan {keys {quote assert}}} {
    set out {}
    if {![regexp -nocase {(quote|assert)[ \t]*=} $text]} { return $out }
    set used {}
    set opened {}
    if {$scan ne ""} {
        foreach blk [dict get $scan blocks] {
            foreach k $keys {
                if {[dict exists [dict get $blk attrs] $k]} { dict set used $k,[dict get $blk lineno] 1 }
            }
        }
        set opened [dict get $scan opened]
    }
    set i 0
    foreach ln [split $text \n] {
        incr i
        if {![regexp -nocase {(quote|assert)[ \t]*=} $ln]} { continue }
        if {![regexp {^(```+|~~~+)[ \t]*(.*)$} [md_strip $ln] -> fence info]} { continue }
        foreach k $keys {
            if {![regexp -nocase "(^|\[ \t\])$k\[ \t\]*=" $info]} { continue }
            if {[dict exists $used $k,$i]} { continue }
            if {$k eq "quote"} {
                set never "where no quote is ever verified"
                set form  "`quote=<revision>`"
                set tail  "it is never verified, so a quote that has rotted there passes silently"
                set what  "a quote="
            } else {
                set never "where no assert= is ever evaluated"
                set form  "`assert=absent` or `assert=present`"
                set tail  "it is never evaluated, so a claim about the tree written there passes silently whether it holds or not"
                set what  "an assert="
            }
            set cause [stray_cause $ln]
            if {$scan eq ""} {
                set cause "in a file with no **STAMP:** line, $never"
            } elseif {$cause ne ""} {
                set cause "a fence that is $cause"
            } elseif {[string index $fence 0] eq "~"} {
                set cause "a ~~~ fence; only ``` fences are read"
            } elseif {[dict exists $opened $i] && ![dict get $opened $i]} {
                set cause "a fence that is never closed"
            } elseif {![dict exists $opened $i]} {
                set cause "inside another fenced block, where it is text, not a fence"
            } else {
                set cause "the attribute is not written $form, lowercase and unspaced"
            }
            lappend out "$num:$i: $what the parser does not read ($cause) -- $tail; write it as a closed, column-0 ``` fence in a stamped file"
        }
    }
    return $out
}

## The quote= half alone -- the proc the self-test and earlier tooling call.
proc istamp::stray_quotes {num text scan} {
    return [stray_attrs $num $text $scan quote]
}

## ---------------------------------------------------------------------------
## THE TREE PREDICATES -- the only things here that touch the repo
## ---------------------------------------------------------------------------

## ⚠ EVERY git CALL HERE THAT CARRIES TEXT FROM AN ISSUE FILE PASSES
## --end-of-options BEFORE IT (git 2.24+; MEASURED on 2.53 for cat-file -e,
## merge-base --is-ancestor and show: an `--output=` value becomes "Not a valid
## object name", exit 128, and nothing is written).  The gate also refuses any
## quote= or tree= that is not a revision token before git is asked at all
## (rev_token), so this is the second lock, not the only one -- and since D16
## each predicate that puts a revision on git's command line checks rev_token
## ITSELF, so a caller that skipped the gate's grammar still hands git nothing
## but hex.  All of them read the history AS STORED (--no-replace-objects here,
## the grafts file off in git_run): the history a stranger's clone receives.
proc istamp::rev_exists {rev} {
    variable repo
    if {![rev_token $rev]} { return 0 }
    if {[catch {git_q $repo --no-replace-objects cat-file -e --end-of-options ${rev}^{commit}} m opt]} {
        return 0
    }
    return 1
}

## What kind of object $rev names IN THIS STORE -- commit, tag, tree, blob --
## or "" when it is not here (or is not a revision token).  Asked only when a
## revision does not resolve to a commit (rev_verdict).  No lazy fetch: the
## question is what this checkout holds, and a partial clone would otherwise go
## to its promisor remote for an object that is not here (MEASURED: `cat-file`
## of an absent full-length name starts `git fetch` in a blob:none clone).
proc istamp::rev_type {rev} {
    variable repo
    if {![rev_token $rev]} { return "" }
    if {[catch {git_env {GIT_NO_LAZY_FETCH 1} 0 $repo --no-replace-objects cat-file -t --end-of-options $rev} t]} {
        return ""
    }
    return [string trim $t]
}

## Is $rev in HEAD's history?  1 yes, 0 no (git's own exit 1), -1 git could
## not say.  In a shallow clone git walks only down to the boundary, so 0
## there means "not reached above it" -- rev_verdict skips it by name.
## ⚠ IN A `full` HISTORY THE SHALLOW FILE IS DISREGARDED HERE TOO (D16).  The
## probe called the tree full because the store holds everything HEAD's history
## needs; asked through a shallow file that names HEAD (a no-op `fetch --depth
## 1`), merge-base answers "not an ancestor" for every real stamp (MEASURED,
## shapes fdself and fdanc: exit 1 honoured, exit 0 disregarded).
proc istamp::rev_is_ancestor {rev} {
    variable repo
    variable noshallow
    if {![rev_token $rev]} { return -1 }
    set envs [expr {[history_state] eq "full" ? $noshallow : {}}]
    if {![catch {git_env $envs 0 $repo --no-replace-objects merge-base --is-ancestor --end-of-options $rev HEAD} m opt]} {
        return 1
    }
    set ec [dict get $opt -errorcode]
    if {[lindex $ec 0] eq "CHILDSTATUS" && [lindex $ec 2] == 1} { return 0 }
    return -1
}

## Does the file <path> at revision <rev> contain this text?  Whitespace-
## normalised on both sides, because a quote that was re-indented is not a
## rotted quote.
##
## THIS IS THE CHECK FOR THE CLASS NOTHING ELSE CATCHES.  A stale line number
## LOOKS stale the moment you follow it.  A stale quoted code block still looks
## like valid C and reads as authoritative -- issues 0296 and 0435 both quote C
## that no longer exists, and A1's phrase for 0435 is exactly right: "correct by
## reference, damaging by paste".  Neither was even scored BAD-FIX, which means
## the count of dangerous stored fixes in this tracker is an UNDERCOUNT.
##
## ⚠ `<rev>:<path>` GOES TO git ON STDIN, NEVER ON ITS COMMAND LINE (D16).  This
## was `git show --end-of-options <rev>:<path>`: a word carrying path=, text from
## the issue file, in an exec.  It began with the hex revision, so it could not
## be read as an option or a redirection -- but "could not, because of what
## precedes it" is exactly the argument that failed one exec over, in
## assert_eval.  `cat-file --batch` reads object names from stdin, where Tcl's
## exec parses nothing and git has no option to take; it prints raw content (no
## textconv, no pager), and the header says whether the name is a FILE.
##
## Returns {1 ""} (holds), {0 <why>} (a finding), or {-1 <why>}: NOT VERIFIED,
## because the file is in that revision and its CONTENT is not in this
## checkout -- a partial clone that never fetched it (quote_gap).  `gapok` is
## 1 only when the gate has verified the revision itself (rev_verdict `ok`):
## a revision that does not resolve is never excused this way.
##
## ⚠ THE -1 EXISTS BECAUSE NO CALL FETCHES ANY MORE (git_always, D19).  In a
## blob:none clone the blob of an old revision's file is simply not here; with
## lazy fetch on, git went and got it (MEASURED red-first, S1-fix7: `git fetch
## ... --filter=blob:none`, packs 8 -> 12, then `ok`), and with it off,
## `cat-file --batch` answers `<rev>:<path> missing` -- the same answer as for a
## path the revision never had.  Reading that as "not a file at that revision"
## would turn a stranger's partial clone RED over a quote that is fine.  So a
## `missing` is looked into, from trees alone (which a blob:none clone holds):
## a path the revision does not have is still RED; a path it has, whose blob a
## PARTIAL clone does not hold, is NOT VERIFIED by name.
proc istamp::quote_holds {rev path body {gapok 0}} {
    variable repo
    if {[catch {git_q $repo --no-replace-objects cat-file --batch << "${rev}:${path}\n"} src]} {
        return [list 0 "git cat-file --batch could not read ${rev}:${path}"]
    }
    set nl   [string first \n $src]
    set head [expr {$nl < 0 ? $src : [string range $src 0 [expr {$nl - 1}]]}]
    if {$gapok && [regexp { missing$} $head]} {
        set gap [quote_gap $rev $path]
        if {$gap ne ""} { return [list -1 $gap] }
    }
    if {![regexp {^[0-9a-f]{40}(?:[0-9a-f]{24})? blob [0-9]+$} $head]} {
        return [list 0 "${rev}:${path} is not a file at that revision (git: [string range $head 0 99])"]
    }
    set src [expr {$nl < 0 ? "" : [string range $src [expr {$nl + 1}] end]}]
    set n_src  [regsub -all {[ \t\r\n]+} $src  { }]
    set n_body [string trim [regsub -all {[ \t\r\n]+} $body { }]]
    if {$n_body eq ""} { return [list 0 "empty quote block"] }
    if {[string first $n_body $n_src] >= 0} { return [list 1 ""] }
    return [list 0 "quoted text is not in ${rev}:${path}"]
}

## Why `<rev>:<path>` is MISSING here although nothing is wrong with it, or ""
## when that cannot be shown (and the quote is then RED as before).  Three
## pieces of evidence, all required, none of them a fetch:
##   * this repository IS a partial clone: its own config (--local; a promisor
##     remote, or git's older extensions.partialclone) says so;
##   * the revision's tree lists the path, as a blob -- `ls-tree -r` reads
##     trees only, which a blob:none clone holds; the revision is a
##     rev_token-checked hex behind --end-of-options, and the path is matched
##     here, in Tcl, never handed to git;
##   * that blob is not in the store (cat-file -e, git's own hex).
## A tree that cannot be listed in a partial clone (a tree:0 filter) is the
## same gap one level up, and is named as such.
proc istamp::quote_gap {rev path} {
    variable repo
    if {![rev_token $rev]} { return "" }
    if {[catch {git_q $repo config --local --get-regexp {^(remote\..+\.promisor|extensions\.partialclone)$}} cfg]} { return "" }
    set partial 0
    foreach ln [split $cfg \n] {
        if {[regexp {^remote\..+\.promisor[ \t]+(.*)$} $ln -> v] && [string tolower [string trim $v]] in {true yes on 1}} { set partial 1 }
        if {[regexp {^extensions\.partialclone[ \t]+(\S+)} $ln]} { set partial 1 }
    }
    if {!$partial} { return "" }
    set want [join [lsearch -all -inline -not -exact [path_parts $path] .] /]
    if {[catch {git_q $repo --no-replace-objects ls-tree -r -z --full-tree --end-of-options $rev} ls]} {
        return "partial clone: the tree of $rev is not in this checkout either, so whether it holds $path cannot be told without fetching, and this checker never fetches"
    }
    foreach ent [split $ls \0] {
        if {![regexp {^[0-7]+ ([a-z]+) ([0-9a-f]{40}(?:[0-9a-f]{24})?)\t(.*)$} $ent -> type oid name]} { continue }
        if {$name ne $want} { continue }
        if {$type ne "blob"} { return "" }
        if {![catch {git_q $repo cat-file -e --end-of-options $oid}]} { return "" }
        return "partial clone: $rev has $want, and its content is not in this checkout -- this checker never fetches"
    }
    return ""
}

## Evaluate a declared assertion about the tree.  Vocabulary is two predicates
## and one pattern token; there is no shell, no interpolation and no way to
## express anything but a search.  That is on purpose: a document that can run
## arbitrary commands when you validate it is a document you cannot validate.
##
## ⚠ AND IT WAS NOT TRUE UNTIL D16, WHICH IS WHY THIS IS NO LONGER A grep.  This
## proc ran `exec timeout 60 /usr/bin/grep -rn -- $pat $target`, and Tcl's exec
## reads ANY word that begins with `>`, `2>`, `<` or `|` as a redirection or a
## pipe -- after `--` as much as before it, since `--` means something to grep
## and nothing to Tcl.  pat= is one token from the issue file.  MEASURED
## (S1-fix4's refuter, and again red-first by S1-fix5, in scratch clones):
##   * `pat=>`  truncated the checkout's README to 0 bytes;
##   * `pat=2>` overwrote it with grep's usage text;
##   * `pat=|` with path= naming a script RAN it -- and `path=../<x>` ran one
##     outside the checkout;
##   * `pat=>/somewhere/pwned` wrote a file outside the checkout while the gate
##     said `ok (0 problems)` and the suite ALL PASS, on three arms;
##   * `pat=2>/dev/null` turned a FALSE assertion green (the text occurs 4 times);
##   * `pat=2>&1` left a file called `&1` in the caller's cwd.
## It predated the batch, and it was live: 1219 is stamped and carries an
## assert= block, so T1 went through that exec on every run.  Escaping the word
## would close the cases someone thought of; not executing anything closes the
## class.  So the files are read HERE, in Tcl, and no exec is involved at all.
##
## WHAT `pat=` MEANS, and it is what those recipes needed it to mean: a LITERAL
## string, searched for byte for byte (its UTF-8 bytes against the file's bytes),
## one hit per LINE that contains it -- grep -rn's count.  Nothing in it is
## special: `.` `*` `[` `^` `$` `\` `|` `>` are themselves.  MEASURED before the
## change: the corpus's only assert= block (1219, `pat=SABOTAGE path=src`) has
## no character a basic regular expression would read specially, and it counts
## 8 either way.  An empty pat= matches nothing and is refused by name.
##
## WHAT IS READ, as `grep -r` read it: path= itself even when it is a symbolic
## link (inside the checkout, see confine_path), every regular file below a
## directory, hidden ones included; a symbolic link met BELOW path= is not
## followed, and a device, FIFO or socket there is skipped -- both exactly as
## grep -r (MEASURED on GNU grep 3.12).  A path= that is itself neither a file
## nor a directory is refused rather than opened: a FIFO would block forever.
## A file holding a NUL byte in which the pattern occurs is NOT counted: grep
## 3.12 reports it on stderr as "binary file matches", which the exec read as a
## failure, so the assertion could not be evaluated -- and it still cannot, by
## name.  (grep also calls a file binary for an encoding error in a UTF-8
## locale; that is locale-dependent and is not reproduced: NUL alone decides.)
## The scan is bounded by its own clock (t_scan), since a Tcl loop is not an
## exec and no `timeout` can wrap it.
##
## ⚠ THE SCAN RUNS IN BYTES, SO EVERY NAME ON DISK IS READ (outsider-fixes
## DECISIONS D18).  Tcl hands `glob`'s names over as TEXT, decoded through the
## system encoding, and `file lstat` encodes that text back.  Under utf-8 --
## this box's default, LANG=C.UTF-8 -- a name that is not valid UTF-8 does not
## come back: `caf\xe9` is listed as "café" and lstat'ed as `caf\xc3\xa9`,
## which is not there, and S1-fix5's scan skipped the entry SILENTLY.
## MEASURED by its refuter, and again red-first by S1-fix6: a token found only
## in src/caf\xe9/note.txt, and a FALSE `assert=absent ... path=src
## state=holds` went `ok (0 problems)` under C.UTF-8 and RED under LANG=C (Tcl's
## system encoding there is iso8859-1) -- a verdict that depended on the locale,
## and a regression, because the grep exec this replaced had read every byte.
## So for the length of one assertion the system encoding is iso8859-1, the
## one encoding in which every byte is one character and back (in_bytes): the
## names glob returns are the directory's own bytes, and lstat and open are
## handed exactly those.  The checkout's root enters as the bytes the system
## encoding made of it; path= and pat= enter as UTF-8, the corpus's own
## encoding, so `path=src/café` names the same directory in every locale.
## Every path a sentence names goes through bytes_shown on the way out.
## ⚠ AND THE FAIL-CLOSED FALLBACK STAYS: an entry a directory lists that lstat
## still cannot see is a NAMED reason the assertion cannot be evaluated
## (scan_dir), never a skip.  Row Q9 holds both halves, under both encodings.
##
## Returns [list holds_p hits detail]; holds_p -1 when it cannot be evaluated.
proc istamp::assert_eval {kind pat path} {
    variable repo
    if {$kind ni {absent present}} {
        return [list -1 -1 "unknown assert kind `$kind`"]
    }
    if {$pat eq ""} {
        return [list -1 -1 "pat= is empty, and an empty pattern names nothing to look for"]
    }
    ## The run's shared clock (t_scan_total): once it has run out, a block is
    ## named without a single file being read.
    lassign [scan_budget] - bmsg bspent
    if {$bspent} { return [list -1 -1 $bmsg] }
    ## Text to bytes BEFORE the switch, each through the encoding that made it.
    set rootb [as_bytes $repo [encoding system]]
    set relb  [as_bytes $path utf-8]
    set patb  [encoding convertto utf-8 $pat]
    if {[catch {in_bytes {
            lassign [confine_path $relb $path $rootb] cst target cwhy
            if {$cst ne "ok"} { error $cwhy }
            assert_scan $target $patb
        }} hits]} {
        return [list -1 -1 $hits]
    }
    if {$kind eq "absent"} {
        return [list [expr {$hits == 0}] $hits ""]
    }
    return [list [expr {$hits > 0}] $hits ""]
}

## The BYTES FORM of text: its bytes in encoding $enc, one character each
## (iso8859-1 is the identity on bytes), for use inside in_bytes.
proc istamp::as_bytes {s enc} {
    return [encoding convertfrom iso8859-1 [encoding convertto $enc $s]]
}

## A bytes-form string as words for a sentence: the UTF-8 it spells when it is
## valid UTF-8, else ASCII with every other byte written \xNN -- so a name that
## no locale can print is still named exactly.  String work only.
proc istamp::bytes_shown {b} {
    set raw [encoding convertto iso8859-1 $b]
    set t [encoding convertfrom utf-8 $raw]
    if {[encoding convertto utf-8 $t] eq $raw} { return $t }
    set out ""
    foreach c [split $b ""] {
        scan $c %c v
        append out [expr {$v < 0x80 ? $c : [format {\x%02x} $v]}]
    }
    return $out
}

## Run $script in the caller's frame with the system encoding iso8859-1, and
## put the encoding back EXACTLY as it was, whatever the script does.  Pure
## Tcl in between -- no exec, no event loop -- so nothing else runs under it.
## Tcl invalidates cached native paths when the system encoding changes
## (Tcl_SetSystemEncoding -> Tcl_FSMountsChanged), so no path computed on one
## side is reused on the other.
proc istamp::in_bytes {script} {
    set old [encoding system]
    encoding system iso8859-1
    set rc [catch {uplevel 1 $script} res opt]
    encoding system $old
    if {$rc} { return -options $opt $res }
    return $res
}

## Why a path= written in an issue file is refused before anything is looked
## at, or "" if its SHAPE is acceptable: relative, not empty, not starting with
## `/` or `-`, and no `..` component.  Shared by assert= (a path in the checkout)
## and quote= (a path in a revision).
proc istamp::path_shape_problem {rel} {
    if {$rel eq ""}                      { return "it is empty" }
    if {[string index $rel 0] eq "/"}    { return "it is an absolute path" }
    if {[string index $rel 0] eq "-"}    { return "it begins with `-`" }
    if {".." in [split $rel /]}          { return "it has a `..` component" }
    return ""
}

## ⚠ path= IS CONFINED TO THE CHECKOUT (outsider-fixes DECISIONS D16).  It was
## `[file join $repo $path]`, handed to grep: an absolute path, `../..`, or a
## symbolic link inside the checkout pointing out of it all read files anywhere
## on the machine (MEASURED red-first, S1-fix5: a token in a directory beside
## the clone was FOUND through each of them), and with the exec they ran them.
## And `file join` is unsafe on its own: in Tcl 8.6 a component spelled `~name`
## is a home-directory lookup (MEASURED: `file join /a ~b` is `~b`).  So:
##   * the SHAPE first, by string, with nothing looked at (path_shape_problem);
##   * then each component is walked from the checkout's real root, by string
##     and lstat, following a symbolic link only where it points INSIDE the
##     checkout -- the walk stops, with nothing beyond the checkout so much as
##     lstat'ed, the moment it would leave (resolve_in).
## Returns {ok <real path> ""} | {refused "" <why>} | {missing "" <why>} |
## {error "" <why>}, every <why> a sentence naming path=.
## ⚠ CALLED INSIDE in_bytes ONLY: `rel` and `rootb` are bytes forms (path= as
## UTF-8, the checkout's root as the system encoding made it), and `shown` is
## path= as the issue file wrote it, for the sentences.
proc istamp::confine_path {rel shown rootb} {
    set rule "an assert= path must be a relative path inside this checkout -- no leading `/` or `-`, no `..`, and no symbolic link out of it -- and nothing outside the checkout is ever read"
    set shape [path_shape_problem $rel]
    if {$shape ne ""} {
        return [list refused "" "path=$shown is refused: $shape; $rule"]
    }
    lassign [resolve_abs $rootb] rst root
    if {$rst ne "ok"} {
        return [list error "" "path=$shown cannot be resolved: the checkout's own path does not ([bytes_shown $root])"]
    }
    lassign [resolve_in $root $rel] st where
    switch -- $st {
        ok      { return [list ok $where ""] }
        out     { return [list refused "" "path=$shown is refused: it leaves the checkout through a symbolic link (to `[bytes_shown $where]`); $rule"] }
        missing { return [list missing "" "path=$shown does not exist in this checkout"] }
        default { return [list error "" "path=$shown cannot be resolved: [bytes_shown $where]"] }
    }
}

## The components of a path, split on `/` by STRING -- never `file split`,
## which rewrites a `~name` component as `./~name`.
proc istamp::path_parts {p} {
    set out {}
    foreach c [split $p /] { if {$c ne ""} { lappend out $c } }
    return $out
}

## One step of a walk: lstat `$cur/$c`.  Returns {link <target>}, {node <type>},
## {missing ""} or {err <why>}.
proc istamp::walk_step {next} {
    if {[catch {file lstat $next st} e eo]} {
        set ec [dict get $eo -errorcode]
        if {[lindex $ec 0] eq "POSIX" && [lindex $ec 1] in {ENOENT ENOTDIR}} { return [list missing ""] }
        return [list err "cannot look at `$next`: [lindex [split $e \n] 0]"]
    }
    if {$st(type) eq "link"} {
        if {[catch {file readlink $next} t]} { return [list err "cannot read the link `$next`: $t"] }
        return [list link $t]
    }
    return [list node $st(type)]
}

## The real path of an ABSOLUTE path, every symbolic link on the way followed.
## {ok <path>} | {missing <path>} | {err <why>}.  Used for the checkout's own
## root, so that confinement compares real paths with real paths.
proc istamp::resolve_abs {path} {
    set cur ""
    set todo [path_parts $path]
    set hops 0
    while {[llength $todo]} {
        set c [lindex $todo 0]
        set todo [lrange $todo 1 end]
        if {$c eq "."} { continue }
        if {$c eq ".."} { set cur [string range $cur 0 [expr {[string last / $cur] - 1}]] ; continue }
        set next "$cur/$c"
        lassign [walk_step $next] k v
        switch -- $k {
            missing { return [list missing $next] }
            err     { return [list err $v] }
            link {
                if {[incr hops] > 40} { return [list err "too many symbolic links under `$path`"] }
                if {[string index $v 0] eq "/"} { set cur "" }
                set todo [concat [path_parts $v] $todo]
            }
            default { set cur $next }
        }
    }
    return [list ok [expr {$cur eq "" ? "/" : $cur}]]
}

## Walk `rel` down from `root` (a REAL path) and never leave it.  A `..` at the
## root, or a link whose target lies outside the root, answers {out <where>}
## before anything beyond the root is lstat'ed.  An absolute link target is
## accepted only when it names the root or a path under it BY STRING (a target
## that reaches the checkout through some other symbolic link is refused: the
## conservative direction).  {ok <path>} | {out <where>} | {missing <path>} |
## {err <why>}.
proc istamp::resolve_in {root rel} {
    set cur $root
    set todo [path_parts $rel]
    set hops 0
    while {[llength $todo]} {
        set c [lindex $todo 0]
        set todo [lrange $todo 1 end]
        if {$c eq "."} { continue }
        if {$c eq ".."} {
            if {$cur eq $root} { return [list out "above the checkout"] }
            set cur [string range $cur 0 [expr {[string last / $cur] - 1}]]
            continue
        }
        set next "$cur/$c"
        lassign [walk_step $next] k v
        switch -- $k {
            missing { return [list missing $next] }
            err     { return [list err $v] }
            link {
                if {[incr hops] > 40} { return [list err "too many symbolic links"] }
                if {[string index $v 0] eq "/"} {
                    if {$v eq $root} {
                        set cur $root
                        set v ""
                    } elseif {[string first "$root/" $v] == 0} {
                        set cur $root
                        set v [string range $v [string length "$root/"] end]
                    } else {
                        return [list out $v]
                    }
                }
                set todo [concat [path_parts $v] $todo]
            }
            default { set cur $next }
        }
    }
    return [list ok $cur]
}

## Count the lines holding the pattern's bytes `patb`, literally, under the
## real path `target` (a file or a directory; a bytes form -- see in_bytes), as
## `grep -rn` counted them.  Throws, with a sentence, when it cannot: an
## unreadable file or directory, an entry that cannot be looked at, a binary
## file that matches, a path= that is neither file nor directory, the budget
## spent.
proc istamp::assert_scan {target patb} {
    lassign [scan_budget] deadline bmsg
    lassign [walk_step $target] k ty
    if {$k ne "node"} { error "`[bytes_shown $target]` cannot be looked at" }
    switch -- $ty {
        file      { return [scan_file $target $patb] }
        directory { return [scan_dir $target $patb $deadline $bmsg] }
        default   { error "`[bytes_shown $target]` is a $ty, not a file or a directory, so it is not opened" }
    }
}

## The deadline one scan must meet, as {deadline words spent}: its own t_scan,
## or the gate() run's shared deadline when that comes first -- with the
## sentence a scan that misses it throws, and whether it is ALREADY missed.
proc istamp::scan_budget {} {
    variable t_scan
    variable t_scan_total
    variable scan_deadline
    set now [clock milliseconds]
    set own [expr {$now + 1000 * $t_scan}]
    if {$scan_deadline ne "" && $scan_deadline <= $own} {
        return [list $scan_deadline "the search ran past the gate's total budget of $t_scan_total s for all the assert= scans of one run -- a corpus that asks for more scanning than that is not evaluated past it, and each assertion reached after it is named instead" [expr {$now > $scan_deadline}]]
    }
    return [list $own "the search ran past its $t_scan s budget" 0]
}

proc istamp::scan_dir {d patb deadline {bmsg ""}} {
    variable t_scan
    if {$bmsg eq ""} { set bmsg "the search ran past its $t_scan s budget" }
    if {![file readable $d] || ![file executable $d]} {
        error "cannot read the directory `[bytes_shown $d]`"
    }
    if {[catch {concat [glob -nocomplain -directory $d *] [glob -nocomplain -directory $d -types hidden *]} kids]} {
        error "cannot list the directory `[bytes_shown $d]`: [bytes_shown $kids]"
    }
    set n 0
    foreach k $kids {
        set base [string range $k [expr {[string last / $k] + 1}] end]
        if {$base in {. ..}} { continue }
        if {[clock milliseconds] > $deadline} {
            error $bmsg
        }
        ## Built by string from the directory already walked -- the name as
        ## the directory holds it, never through `file join` (see confine_path).
        set p "$d/$base"
        ## ⚠ NEVER `continue` HERE.  This was `if {[catch {file lstat $p st}]}
        ## { continue }`, and a name that did not round-trip through the system
        ## encoding vanished from the count without a word (see assert_eval).
        ## in_bytes makes every listed name round-trip; anything that STILL
        ## cannot be looked at means the count would be short, so the assertion
        ## is not evaluated, by name.
        if {[catch {file lstat $p st} e]} {
            error "cannot look at `[bytes_shown $p]`, which its directory lists ([bytes_shown [lindex [split $e \n] 0]]) -- what it holds cannot be counted, so the search would come up short"
        }
        switch -- $st(type) {
            directory { incr n [scan_dir $p $patb $deadline $bmsg] }
            file      { incr n [scan_file $p $patb] }
            default   {}
        }
    }
    return $n
}

proc istamp::scan_file {f patb} {
    ## An absolute path, so `open` can never read it as a pipe (`|...`).
    if {[string index $f 0] ne "/"} { error "internal: `[bytes_shown $f]` is not an absolute path" }
    if {[catch {open $f r} fh]} {
        error "cannot read `[bytes_shown $f]`: [bytes_shown [lindex [split $fh \n] 0]]"
    }
    fconfigure $fh -translation binary
    set rc [catch {read $fh} data]
    close $fh
    if {$rc} { error "cannot read `[bytes_shown $f]`: [bytes_shown [lindex [split $data \n] 0]]" }
    set i [string first $patb $data]
    if {$i < 0} { return 0 }
    if {[string first \x00 $data] >= 0} {
        error "`[bytes_shown $f]` is a binary file (it holds a NUL byte) and the pattern occurs in it -- grep reports such a file without a line count, so none is taken here either"
    }
    set n 0
    while {$i >= 0} {
        incr n
        set e [string first \n $data $i]
        if {$e < 0} { break }
        set i [string first $patb $data [expr {$e + 1}]]
    }
    return $n
}

## ---------------------------------------------------------------------------
## THE BASELINE -- identity, not a count
## ---------------------------------------------------------------------------

## {1 <set>} read; {0 {}} absent; {-1 {} <why>} present and not usable -- not a
## regular file (never opened: see not_regular), unreadable, or a line that is
## not an issue file's name.  ⚠ lstat, not `file exists`, which follows a
## link: a baseline that was a symbolic link to a file outside the checkout was
## READ, and one that was a FIFO blocked the gate until an external timeout
## (MEASURED red-first, S1-fix6).
##
## <set> is keyed by EXACT FILE NAME -- `0057-some-slug.md` -- never by number
## (see the header: a colliding number is not an identity).  Every line that is
## not blank or a `#` comment must be one canonical issue file name; anything
## else makes the whole baseline UNUSABLE, by line: a bare number is the old
## format, which would exempt every file that ever takes that number, and a
## line the reader silently skipped would un-grandfather a file without a word.
proc istamp::load_baseline {} {
    variable baseline
    set s {}
    if {[catch {file lstat $baseline st} e eo]} {
        set ec [dict get $eo -errorcode]
        if {[lindex $ec 0] eq "POSIX" && [lindex $ec 1] in {ENOENT ENOTDIR}} { return [list 0 $s] }
        return [list -1 $s "cannot be looked at ([lindex [split $e \n] 0])"]
    }
    set nr [not_regular $baseline]
    if {$nr ne ""} { return [list -1 $s $nr] }
    if {[catch {read_file $baseline} text]} {
        return [list -1 $s "cannot be read ([lindex [split $text \n] 0])"]
    }
    set i 0
    foreach ln [split $text \n] {
        incr i
        set ln [string trim $ln]
        if {$ln eq "" || [string index $ln 0] eq "#"} { continue }
        if {[canonical_name $ln]} { dict set s $ln 1 ; continue }
        if {[regexp {^[0-9]{4}$} $ln]} {
            return [list -1 {} "has a bare issue number on line $i (`$ln`) -- the baseline grandfathers exact file names (`NNNN-<slug>.md`), because a number would exempt every file that ever takes it, and this project's clones mint colliding numbers"]
        }
        return [list -1 {} "has a line that is not an issue file's name on line $i (`[string range $ln 0 59]`) -- every line must be a comment or one `NNNN-<slug>.md`"]
    }
    return [list 1 $s]
}

## The ONE rule for an issue file's name: four digits, a dash, anything, `.md`.
## issue_files reads exactly these; load_baseline accepts exactly these.
proc istamp::canonical_name {n} {
    return [regexp {^[0-9]{4}-.*\.md$} $n]
}

## An issue file's name as the corpus spells it -- the UTF-8 reading of its
## bytes -- whatever the system encoding decoded it as, so that a name in the
## baseline (a UTF-8 file) matches the name in the listing in every locale.
proc istamp::name_key {n} {
    return [encoding convertfrom utf-8 [encoding convertto [encoding system] $n]]
}

## ⚠ AN ISSUE FILE, AND THE BASELINE, MUST BE A REGULAR FILE -- asked with
## lstat BEFORE anything opens it (outsider-fixes DECISIONS D18).  read_file
## is `open`, which follows a symbolic link and blocks on a FIFO.  MEASURED by
## S1-fix5's refuter and again red-first by S1-fix6, in scratch clones: an
## issue file that was a symbolic link to a file OUTSIDE the checkout was read
## and its stamp checked ("1601: tree=deadbee0 does not resolve"); one that was
## a link to a FIFO -- git cannot store a FIFO, but it stores a link to one --
## blocked the gate in `open` until an external `timeout` killed it (rc 124,
## the checker has no bound of its own on a Tcl call); a plain FIFO and a FIFO
## baseline did the same.  So anything that is not a regular file is a named
## problem and is never opened.  A link that points INSIDE the checkout is
## refused too: the rule is about what the entry IS, so no target can argue
## with it, and git tracks issue files as files.
## "" for a regular file, else the words saying what $path is.
proc istamp::not_regular {path} {
    if {[catch {file lstat $path st} e]} {
        return "cannot be looked at ([lindex [split $e \n] 0])"
    }
    switch -- $st(type) {
        file    { return "" }
        link    {
            set to [expr {[catch {file readlink $path} t] ? "?" : $t}]
            return "is a symbolic link (to `$to`), not a regular file"
        }
        default { return "is a $st(type), not a regular file" }
    }
}

## ⚠ AND THE CORPUS DIRECTORY STAYS INSIDE THE CHECKOUT.  `doc/claude/issues`
## (or `doc`, or `doc/claude`) committed as a symbolic link out of the checkout
## would hand every `NNNN-*.md` under its target to the gate -- the same read
## outside the checkout as a linked issue file, one level up.  Walked from the
## checkout's real root by resolve_in, which never lstats anything beyond the
## root.  Asked only of the checkout's OWN corpus: a corpus handed to
## `gate <issuesdir> <baseline>`, or to with_corpus by the suite, is the
## caller's choice of directory.  A corpus directory that is simply absent is
## an empty corpus, as it always was.  "" or the problem.
proc istamp::issues_dir_problem {} {
    variable repo
    variable issues_dir
    if {$issues_dir ne [file join $repo doc claude issues]} { return "" }
    lassign [resolve_abs $repo] rst root
    if {$rst ne "ok"} {
        return "CORPUS UNREADABLE: the checkout's own path cannot be resolved ($root), so where doc/claude/issues leads cannot be checked -- no issue file is read"
    }
    lassign [resolve_in $root doc/claude/issues] st where
    switch -- $st {
        out     { return "CORPUS OUTSIDE THE CHECKOUT: doc/claude/issues leads out of it through a symbolic link (to `$where`) -- no issue file is read, because nothing outside the checkout ever is" }
        err     { return "CORPUS UNREADABLE: doc/claude/issues cannot be resolved ($where) -- no issue file is read" }
        default { return "" }
    }
}

proc istamp::issue_files {} {
    variable issues_dir
    set out {}
    foreach f [lsort [glob -nocomplain -tails -directory $issues_dir *.md]] {
        if {[canonical_name $f] && [regexp {^([0-9]{4})-} $f -> num]} { lappend out $num $f }
    }
    return $out
}

## Names in the issues directory that LOOK like issue files -- they begin with
## a digit and end in `.md`, in any case -- and miss the canonical name, so
## issue_files never lists them and the gate would never read them: an
## unstamped file called `1601_x.md` or `1601.md` or `1601-x.MD` was simply
## invisible (MEASURED red-first, S1-fix7: `ok (0 problems)` for each).  Named,
## never opened.  NNNN-<slug>.patch and the like are attachments, not issue
## files, and are not matched.  MEASURED 2026-09-18 at aa5cece0: the real
## directory holds 1059 entries, 1047 canonical, and NONE of this shape.
proc istamp::misnamed_files {} {
    variable issues_dir
    set out {}
    foreach f [lsort [glob -nocomplain -tails -directory $issues_dir *]] {
        if {[regexp -nocase {^[0-9].*\.md$} $f] && ![canonical_name $f]} { lappend out $f }
    }
    return $out
}

## ---------------------------------------------------------------------------
## THE GATE
## ---------------------------------------------------------------------------
##
## Returns a list of problem strings.  Empty list = green.
## `opts` may carry -headerlines N (default 12).

## The run's assert= scans share ONE clock (t_scan_total, see there): set here,
## cleared on every way out, so a scan outside a gate() run -- a suite row
## calling assert_eval directly -- has only its own per-scan budget.
proc istamp::gate {args} {
    variable scan_deadline
    variable t_scan_total
    set scan_deadline [expr {[clock milliseconds] + 1000 * $t_scan_total}]
    set rc [catch {gate_body {*}$args} res opt]
    set scan_deadline ""
    if {$rc} { return -options $opt $res }
    return $res
}

proc istamp::gate_body {args} {
    variable issues_dir
    variable ok_claim
    variable last_skips
    variable last_verified
    variable rev_cache
    set headerlines 12
    foreach {k v} $args { if {$k eq "-headerlines"} { set headerlines $v } }

    set last_skips    {}
    set last_verified 0
    set rev_cache     {}
    set problems {}
    lassign [load_baseline] have_base base bwhy
    if {$have_base == 0} {
        lappend problems "BASELINE MISSING: tests/headless/issue_stamp_baseline.txt does not exist -- without it every unstamped file would read as a new violation, so the gate refuses to run rather than emit 1047 false reds"
        return $problems
    }
    if {$have_base < 0} {
        lappend problems "BASELINE UNUSABLE: tests/headless/issue_stamp_baseline.txt $bwhy -- it is not opened, and without it every unstamped file would read as a new violation, so the gate refuses to run"
        return $problems
    }

    set stamped {}          ;# num -> fields
    set dp [issues_dir_problem]
    if {$dp ne ""} {
        lappend problems $dp
        return $problems
    }
    set files [issue_files]
    foreach f [misnamed_files] {
        lappend problems "$f: looks like an issue file but is not named `NNNN-<slug>.md` (four digits, a dash, lowercase `.md`), so the gate does not read it as one -- nothing in it is checked, and an unstamped file named this way would pass unseen; rename it"
    }

    foreach {num fname} $files {
        set path [file join $issues_dir $fname]
        ## lstat FIRST: a link or a FIFO is named and never opened (not_regular).
        set nr [not_regular $path]
        if {$nr ne ""} {
            lappend problems "$num ($fname): $nr -- an issue file must be a regular file, so it is not opened: a symbolic link can lead out of the checkout, and a FIFO or a device would block the gate"
            continue
        }
        if {[catch {read_file $path} text]} {
            lappend problems "$num: unreadable ($text)"
            continue
        }
        ## Text written to be a stamp, a quote or an assertion that the parser
        ## does not read: a problem wherever it sits (see TEXT THE PARSER DOES
        ## NOT READ).
        lappend problems {*}[stray_stamps $num $text]
        set fs [find_stamp $text]
        set n [dict get $fs n]
        if {$n == 0} {
            ## Unstamped.  Grandfathered by its EXACT FILE NAME, or it is a
            ## violation -- never by number (see load_baseline).
            if {![dict exists $base [name_key $fname]]} {
                lappend problems "$num ($fname): a NEW issue file with no **STAMP:** line. Every issue filed after the convention landed must carry one -- see doc/claude/specs/issue_stamp.md. The unconverted set may shrink, never grow."
            }
            lappend problems {*}[stray_attrs $num $text ""]
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
        ## The fences, once: which blocks were read, and which fences opened.
        ## A quote= the parser did not read is reported here, before the
        ## revision question, so it is named whatever the history state.
        set scan [fence_scan $text]
        lappend problems {*}[stray_attrs $num $text $scan]
        ## ⚠ A REVISION THAT DOES NOT RESOLVE, OR RESOLVES OFF HEAD'S HISTORY, IS
        ## A FINDING WHEREVER THERE IS HISTORY TO ASK (see HISTORY above and
        ## rev_verdict).  Only where the answer is provably absent -- beyond a
        ## shallow clone's boundary, or no commits at all -- is the revision NOT
        ## VERIFIED, recorded by name in last_skips, and every check below that
        ## does not need it still runs: the header window, the grammar and the
        ## baseline are already behind us, and assert= and the mirror check are
        ## grep and dict work.  The date is not consulted.
        lassign [rev_verdict [dict get $f tree]] rv rwhy
        switch -- $rv {
            ok   { incr last_verified }
            skip { lappend last_skips "$num: tree=[dict get $f tree] ($rwhy)" }
            default {
                if {$rwhy eq "unresolved"} {
                    lappend problems "$num: tree=[dict get $f tree] does not resolve to a commit in this repo. The whole value of the stamp is that `git show [dict get $f tree]:<file>` recovers every coordinate in the file; a revision that does not resolve recovers nothing.[upstream_note]"
                } else {
                    lappend problems "$num: [rev_problem tree=[dict get $f tree] [dict get $f tree] $rwhy]"
                }
                continue
            }
        }
        dict set stamped $num $f

        ## --- checks that apply only to stamped files (forward enforcement) ---
        foreach blk [dict get $scan blocks] {
            set a [dict get $blk attrs]
            set ln [dict get $blk lineno]
            ## A marked fence whose info string holds a word the grammar does
            ## not read is NOT evaluated as the weaker claim its readable words
            ## make (fence_info): it is named, and nothing it claims passes.
            if {[llength [dict get $blk bad]]} {
                lappend problems "$num:$ln: a marked fence the parser cannot read in full -- [join [dict get $blk bad] {; }] -- so the block is not evaluated and nothing it claims is checked; write at most one language word, then key=value words only, each key once (pat= is ONE whitespace-free token)"
                continue
            }
            if {[dict exists $a quote]} {
                if {![dict exists $a path]} {
                    lappend problems "$num:$ln: a quote= block must also carry path="
                    continue
                }
                set q [dict get $a quote]
                ## ⚠ NOTHING THAT IS NOT A REVISION REACHES git (rev_token).
                if {![rev_token $q]} {
                    lappend problems "$num:$ln: quote=[string range $q 0 59] is not a revision (7-40 hex, at least one a-f) -- a quote names the revision its text was copied from, and nothing else in an issue file is ever handed to git"
                    continue
                }
                ## ...and its path= names a file IN that revision: relative, no
                ## `..`, no leading `/` or `-` (D16) -- refused before git is asked.
                set qps [path_shape_problem [dict get $a path]]
                if {$qps ne ""} {
                    lappend problems "$num:$ln: a quote= block's path=[string range [dict get $a path] 0 79] is refused: $qps -- it names a file inside the repository at that revision"
                    continue
                }
                ## `git show <rev>:<path>` needs the revision itself, so a quote
                ## is verifiable exactly when its revision is.  An unresolved
                ## `bad` falls through to quote_holds, which fails on it by name;
                ## a revision off HEAD's history is refused HERE, because
                ## `git show` would find it in this store and pass it.
                lassign [rev_verdict $q] qv qwhy
                if {$qv eq "skip"} {
                    lappend last_skips "$num:$ln: quote=$q path=[dict get $a path] ($qwhy)"
                } elseif {$qv eq "bad" && $qwhy ne "unresolved"} {
                    lappend problems "$num:$ln: [rev_problem quote=$q $q $qwhy]"
                } else {
                    ## Only a revision that is VERIFIED may have its missing
                    ## content excused as a partial clone's (quote_holds).
                    lassign [quote_holds [dict get $a quote] [dict get $a path] [dict get $blk body] [expr {$qv eq "ok"}]] ok why
                    if {$ok == -1} {
                        lappend last_skips "$num:$ln: quote=$q path=[dict get $a path] ($why)"
                    } elseif {!$ok} {
                        set qn [expr {$qv eq "bad" ? [upstream_note] : ""}]
                        lappend problems "$num:$ln: $why -- a quoted block that no longer matches its source still LOOKS like valid code, and is the direct on-ramp to a fix that damages working code[expr {$qn ne "" ? ".$qn" : ""}]"
                    }
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
    ## construction.  That sentence is not mine: it is a comment in
    ## src/op_annot.tcl, above the seven-class truth table, written about
    ## mirroring another MODULE's rules, and it applies verbatim to prose.
    ## 0071 is the proof -- its child tables restate six children's statuses and
    ## four of them had drifted.
    ##
    ## ⚠ THIS COMMENT SAID "issue 0442's own header" UNTIL BC2 CHECKED IT, and
    ## the sentence is not in 0442 anywhere: /usr/bin/grep -c over that file
    ## answers 0 at d09ebece.  A misattributed quote, inside the checker written
    ## to stop misattributed quotes.  The claim was true and the citation was
    ## invented -- which is this corpus's dominant defect (ROTTED-CITE, 27 of 40)
    ## reproducing itself in its own cure.  Found by D1 (receipt F4).
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
    variable selftest_n
    set bad {}
    set n 0
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
    incr n [llength $good]
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
        {**STAMP:** `v1 claim=open tree=d64686a1 stamped=0000-00-00 fix=none open=0`}
            {the right shape and no day at all -- a date rule once trusted exactly this}
        {**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-02-30 fix=none open=0`}
            {a day the month does not have}
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
    incr n [expr {[llength $badcases] / 2}]
    ## The formatter and the parser must agree.
    set rt [format_stamp [dict create claim open tree d64686a1 stamped 2026-09-17 fix none open 3]]
    set p [parse_stamp $rt]
    if {![dict get $p ok]} { lappend bad "round-trip failed: $rt -- [dict get $p err]" }
    incr n
    ## ⚠ AND ONE ROUND-TRIP CARRYING EVERY OPTIONAL FIELD, ASSERTED AS A WHOLE
    ## DICT RATHER THAN AS `ok`.  The fixture above carries only the five
    ## REQUIRED keys and asks only whether the result PARSES -- so format_stamp,
    ## whose key list omitted `scope` entirely, round-tripped GREEN while
    ## silently deleting the one field that records a defect closed on ONE route
    ## and live on another.  0216 (fixed for the Location bar and
    ## wviewer::restore, NOT for the ASE re-run path) and 0650 (general channel
    ## landed, titular session-window sink did not) both carry a scope today,
    ## and dropping it closes a live defect: the STALE-OPEN direction, the one
    ## this design calls the dangerous one.
    ##
    ## A round-trip fixture whose INPUT lacks a field cannot detect a formatter
    ## that drops it.  That is the vacuous-green family arriving for the THIRD
    ## time in this batch -- BC1's rev_exists, BC1's row B1, and this -- and
    ## twice now inside the very machinery built to treat it.  Asserting the
    ## whole dict means a key added to the grammar and forgotten in the
    ## formatter reddens HERE, not in a corpus six months from now.
    set full [dict create claim partial tree 61af3692 stamped 2026-09-17 \
                          fix taken open 1 super 0655 scope ase-rerun-path by D1]
    set rt2 [format_stamp $full]
    set p2  [parse_stamp $rt2]
    if {![dict get $p2 ok]} {
        lappend bad "round-trip (every field) did not parse: $rt2 -- [dict get $p2 err]"
    } elseif {[dict_canon [dict get $p2 f]] ne [dict_canon $full]} {
        lappend bad "round-trip LOST OR CHANGED a field: wrote {[dict_canon $full]}, read back {[dict_canon [dict get $p2 f]]} via $rt2"
    }
    incr n
    ## ⚠ THE REVISION GRAMMAR, AND THE UNREAD-TEXT DETECTORS, ON KNOWN ANSWERS.
    ## The real corpus holds no quote= block and no stray stamp (MEASURED), so
    ## without these the gate would print a green from detectors that were
    ## never handed an input -- the vacuous-green family again.  Known
    ## negatives ride with the positives, so no detector passes by firing on
    ## everything: 0993's C in prose, a stamp mentioned mid-sentence, and a
    ## column-0 fence that closes are each worth nothing.
    set s  "`v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=0`"
    set rc {61af3692 1 --output=/tmp/x 0 HEAD 0 16091816 0}
    foreach {tok want} $rc {
        if {[rev_token $tok] != $want} { lappend bad "rev_token $tok: got [rev_token $tok], want $want" }
        incr n
    }
    ## (The mid-sentence mention carries `v1 ...`, not a whole body: since D19 a
    ## line holding a whole stamp body that is not read is named -- see bc below.)
    set sc [list "  **STAMP:** $s" 1 "> **STAMP:** $s" 1 "**stamp:** $s" 1 \
                 "# see **STAMP:** `v1 ...` in the spec" 0 "**STAMP:** $s" 0]
    foreach {txt want} $sc {
        set got [llength [stray_stamps 9999 $txt]]
        if {$got != $want} { lappend bad "stray_stamps found $got, want $want, in: $txt" }
        incr n
    }
    set qc [list "  ```c quote=d64686a1 path=x\n  y\n  ```" 1 \
                 "~~~c quote=d64686a1 path=x\ny\n~~~" 1 \
                 "```c quote=d64686a1 path=x\ny" 1 \
                 "```text\n```c quote=d64686a1 path=x\ny\n```" 1 \
                 "```c quote=d64686a1 path=x\ny\n```" 0 \
                 "(`if(c=='\"') quote=!quote;`)\n```c\nquote=!quote;\n```" 0]
    foreach {txt want} $qc {
        set got [llength [stray_quotes 9999 $txt [fence_scan $txt]]]
        if {$got != $want} { lappend bad "stray_quotes found $got, want $want, in: [string map [list \n { | }] $txt]" }
        incr n
    }
    ## D16: a stamp in markdown's OTHER bold spellings, plain, or with the colon
    ## outside the emphasis, is stamp-shaped; a word that merely ends in "stamp"
    ## and bold prose that is not "Stamp:" are not.
    set sc2 [list "__STAMP:__ $s" 1 "<strong>STAMP:</strong> $s" 1 "<b>STAMP:</b> $s" 1 \
                  "STAMP: $s" 1 "**STAMP**: $s" 1 "_Stamp:_ see below" 1 \
                  "Timestamp: 2026-09-18" 0 "**Stamp the record** with a token" 0 \
                  "Stamp: the v2 layout" 0]
    foreach {txt want} $sc2 {
        set got [llength [stray_stamps 9999 $txt]]
        if {$got != $want} { lappend bad "stray_stamps found $got, want $want, in: $txt" }
        incr n
    }
    ## D16: fences close the CommonMark way -- same character, at least as long,
    ## indented at most 3 -- as {blocks read, body of the first}.
    set fc [list "````c quote=d64686a1 path=x\na\n```\nb\n````" [list 1 "a\n```\nb"] \
                 "```c quote=d64686a1 path=x\na\n`````\nb" [list 1 a] \
                 "```c quote=d64686a1 path=x\na\n  ```\nb" [list 1 a] \
                 "```c quote=d64686a1 path=x\na\n~~~\n```" [list 1 "a\n~~~"] \
                 "~~~\n```c quote=d64686a1 path=x\na\n```\n~~~" [list 0 {}] \
                 "  ```text\n```c quote=d64686a1 path=x\na\n  ```" [list 0 {}]]
    foreach {txt want} $fc {
        set blks [dict get [fence_scan $txt] blocks]
        set got [list [llength $blks] [expr {[llength $blks] ? [dict get [lindex $blks 0] body] : {}}]]
        if {$got ne $want} { lappend bad "fence_scan read {$got}, want {$want}, in: [string map [list \n { | }] $txt]" }
        incr n
    }
    ## ...and a quote fence that is TEXT inside a ~~~ block is named, not read.
    set t9 "~~~\n```c quote=d64686a1 path=x\na\n```\n~~~"
    set got [llength [stray_quotes 9999 $t9 [fence_scan $t9]]]
    if {$got != 1} { lappend bad "stray_quotes found $got, want 1, in: [string map [list \n { | }] $t9]" }
    incr n
    ## D18: an assert= the parser does not read is named as a quote= is -- in a
    ## ~~~ fence, an indented one, a blockquote, one never closed, and in a file
    ## with no stamp -- while a READ assert= fence and assert= in prose are not.
    ## As {text stamped? want}.
    set a "assert=absent pat=x path=y state=holds"
    set ac [list "~~~sh $a\nz\n~~~" 1 1   "  ```sh $a\n  z\n  ```" 1 1   "> ```sh $a\n> z\n> ```" 1 1 \
                 "```sh $a\nz" 1 1        "```sh $a\nz\n```" 0 1        "```sh $a\nz\n```" 1 0 \
                 "the gate reads $a in a fence, never in prose" 1 0]
    foreach {txt st want} $ac {
        set got [llength [stray_attrs 9999 $txt [expr {$st ? [fence_scan $txt] : ""}]]]
        if {$got != $want} { lappend bad "stray_attrs found $got, want $want, in ([expr {$st ? "stamped" : "unstamped"}]): [string map [list \n { | }] $txt]" }
        incr n
    }
    ## D18: md_strip in one pass gives the loop's answers.
    set mc [list "  > - 1. # **STAMP:** x" "**STAMP:** x"   ">>>x" "x"   "12.x" "12.x"   "-x" "-x"   "#x" "#x"]
    foreach {txt want} $mc {
        set got [md_strip $txt]
        if {$got ne $want} { lappend bad "md_strip gave <$got>, want <$want>, for <$txt>" }
        incr n
    }
    ## D19: a marked fence's info string is read in FULL -- as {attrs-count
    ## bad-count}.  The refuter's two multi-word pat= spellings, a key the
    ## grammar does not know, a key given twice; and the known negatives: a
    ## well-formed marked fence (with and without a language word), and an
    ## ordinary code fence whose info string has words but no key=value at all.
    set ic [list {sh assert=absent pat="static int" path=src state=holds} {4 1} \
                 {sh assert=present pat=static nonexistent_zz_symbol path=src state=holds} {4 1} \
                 {sh assert=absent pat=x path=src state=holds pth=src} {4 1} \
                 {sh assert=absent pat=x pat=y path=src state=holds} {4 1} \
                 {sh assert=absent pat=x path=src state=holds} {4 0} \
                 {assert=absent pat=x path=src state=holds} {4 0} \
                 {c quote=d64686a1 path=x} {2 0} \
                 {text an ordinary title, no attributes} {0 0}]
    foreach {info want} $ic {
        lassign [fence_info $info] toks fb
        set got [list [expr {[llength $toks] / 2}] [llength $fb]]
        if {$got ne $want} { lappend bad "fence_info read {$got}, want {$want}, for <$info>" }
        incr n
    }
    ## D19: a line holding a stamp's BODY that find_stamp does not read is named
    ## whatever precedes it -- the refuter's colon-less spellings and a stamp
    ## quoted mid-sentence -- while the read stamp and prose that happens to
    ## hold `v1` are not.
    set bc [list "**STAMP** $s" 1 "STAMP $s" 1 "**Stamp** $s" 1 "**STAMP;** $s" 1 \
                 "the stamp we meant was $s, never written" 1 "# see **STAMP:** $s in the spec" 1 "**STAMP:** $s" 0 \
                 "the batch reads `v1 v2 v3` newest-first" 0 "`v1 = 8.333333e-01` is volts" 0]
    foreach {txt want} $bc {
        set got [llength [stray_stamps 9999 $txt]]
        if {$got != $want} { lappend bad "stray_stamps found $got, want $want, in: $txt" }
        incr n
    }
    ## D19: the one rule for an issue file's name.
    set nc [list 1601-x.md 1 1601-.md 1 1601_x.md 0 1601.md 0 1601-x.MD 0 {1601 x.md} 0 160-x.md 0 1601-attempt-1.patch 0]
    foreach {nm want} $nc {
        if {[canonical_name $nm] != $want} { lappend bad "canonical_name $nm: got [canonical_name $nm], want $want" }
        incr n
    }
    set selftest_n $n
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

## ⚠ THE CENSUS OBEYS THE GATE'S RULES FOR WHAT IS READ, AND RUNS NOTHING
## (outsider-fixes DECISIONS D19).  It listed the corpus BEFORE asking
## issues_dir_problem, and its citation counts were `exec timeout 60
## /usr/bin/grep -rnoE ... <repo>/<dir>` -- and grep follows a symbolic link it
## is handed on its command line.  MEASURED by S1-fix6's refuter and red-first by
## S1-fix7: with doc/claude/issues committed as a link to a directory OUTSIDE
## the checkout, `report` said `issue files: 0` and named nothing, while its
## citation count went 4689 -> 9689 -- +5000, exactly the lines planted
## outside; with src such a link, `src: 7000`, every one of them outside.  Its
## own comment promised "an advisory census must not read outside the checkout".
## Now: the corpus directory is asked first and nothing in it is listed when it
## leads out; each counted directory is resolved from the checkout's real root
## by resolve_in, like an assert= path=, and one that leads out is refused by
## name; the count is a Tcl walk (cite_scan) that follows no link below the
## top and opens no FIFO, under one clock for the whole census.  So `report`
## runs no program at all, and the checker's only exec is git.
##
## report_census answers a dict, and `report` only prints it -- so that suite
## row Q13 can hold the census to known answers, which nothing did before.
##   files notopened stamped misnamed  counts over the issue files
##   corpus     "" or the issues_dir_problem sentence
##   baseline   the grandfathered count, or why there is none
##   cites      {label {n why} ...}: n = -1 when not counted, and why says why
namespace eval istamp { variable cite_re {[A-Za-z0-9_./-]+\.(c|h|tcl|sh|py|md)[:][0-9]+} }
proc istamp::report_census {} {
    variable repo
    variable issues_dir
    variable t_scan_total
    set r [dict create files 0 notopened 0 stamped 0 misnamed 0 corpus "" baseline "" cites {}]
    set dp [issues_dir_problem]
    dict set r corpus $dp
    if {$dp eq ""} {
        foreach {num fname} [issue_files] {
            dict incr r files
            set path [file join $issues_dir $fname]
            if {[not_regular $path] ne "" || [catch {read_file $path} text]} { dict incr r notopened ; continue }
            if {[dict get [find_stamp $text] n] > 0} { dict incr r stamped }
        }
        dict set r misnamed [llength [misnamed_files]]
    }
    lassign [load_baseline] hb bset bwhy
    dict set r baseline [expr {$hb > 0 ? [dict size $bset] : ($hb == 0 ? "no baseline file" : "baseline $bwhy")}]
    set deadline [expr {[clock milliseconds] + 1000 * $t_scan_total}]
    set cites {}
    foreach rel {doc/claude/issues src tests} {
        if {$rel eq "doc/claude/issues" && $dp ne ""} {
            lappend cites $rel [list -1 "not counted: the corpus directory leads out of the checkout"]
            continue
        }
        lappend cites $rel [cite_count $rel $deadline]
    }
    dict set r cites $cites
    return $r
}

## {n ""}, or {-1 why}: the coordinate citations under repo-relative `rel`,
## counted as `grep -rnoE` counted them (one per match), read in bytes
## (in_bytes) so every name on disk is seen.  A binary file -- one holding a
## NUL byte -- is not counted, as grep prints no line for it.
proc istamp::cite_count {rel deadline} {
    variable repo
    variable cite_re
    set rootb [as_bytes $repo [encoding system]]
    if {[catch {in_bytes {
            lassign [resolve_abs $rootb] rst root
            if {$rst ne "ok"} { error "not counted: the checkout's own path does not resolve" }
            lassign [resolve_in $root $rel] st where
            switch -- $st {
                ok      {}
                out     { error "not counted: $rel leads out of the checkout through a symbolic link (to `[bytes_shown $where]`), and nothing outside it is read" }
                missing { error "not counted: $rel is not in this checkout" }
                default { error "not counted: $rel cannot be resolved ([bytes_shown $where])" }
            }
            lassign [walk_step $where] k ty
            if {$k ne "node" || $ty ne "directory"} { error "not counted: $rel is not a directory" }
            cite_dir $where $cite_re $deadline
        }} n]} {
        return [list -1 $n]
    }
    return [list $n ""]
}

## scan_dir's walk -- no link below the top followed, nothing but regular files
## opened, every name in bytes -- counting regexp matches instead of lines.
## An entry that cannot be looked at, or a directory that cannot be read, is
## left out of the count (the census is advisory, never a verdict).
proc istamp::cite_dir {d re deadline} {
    if {[catch {concat [glob -nocomplain -directory $d *] [glob -nocomplain -directory $d -types hidden *]} kids]} { return 0 }
    set n 0
    foreach k $kids {
        set base [string range $k [expr {[string last / $k] + 1}] end]
        if {$base in {. ..}} { continue }
        if {[clock milliseconds] > $deadline} { error "not counted: the census ran past its budget" }
        set p "$d/$base"
        if {[catch {file lstat $p st}]} { continue }
        switch -- $st(type) {
            directory { incr n [cite_dir $p $re $deadline] }
            file {
                if {[string index $p 0] ne "/" || [catch {open $p r} fh]} { continue }
                fconfigure $fh -translation binary
                set rc [catch {read $fh} data]
                close $fh
                if {$rc || [string first \x00 $data] >= 0} { continue }
                incr n [regexp -all -- $re $data]
            }
            default {}
        }
    }
    return $n
}

proc istamp::report {} {
    set r [report_census]
    if {[dict get $r corpus] ne ""} { puts "corpus                       : [dict get $r corpus]" }
    puts "issue files                  : [dict get $r files]"
    puts "carrying a **STAMP:** line   : [dict get $r stamped]"
    if {[dict get $r notopened]} { puts "not opened or not readable   : [dict get $r notopened] (the gate names each)" }
    if {[dict get $r misnamed]} { puts "named like an issue file, not NNNN-<slug>.md: [dict get $r misnamed] (the gate names each)" }
    puts "grandfathered (baseline)     : [dict get $r baseline]"
    foreach {label c} [dict get $r cites] {
        lassign $c n why
        puts [format "coordinate citations in %-20s: %s" $label [expr {$n >= 0 ? $n : $why}]]
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
            puts "history: [history_state] -- [history_why]"
            set problems [gate]
            variable last_skips
            ## Every revision the gate could not ask about, BY NAME, and before
            ## the verdict -- so a green here can never be read as "verified".
            foreach s $last_skips { puts "ISSUE-STAMP: NOT VERIFIED $s" }
            set nsk [llength $last_skips]
            ## Only shallow, none and unborn skip a REVISION; full and unreadable
            ## never do.  What a full history can skip is a partial clone's
            ## missing CONTENT, for a quote= (quote_gap), and it says so.
            switch -- [history_state] {
                unborn  { set gap "no commits yet" }
                full    -
                unreadable { set gap "content a partial clone never fetched" }
                default { set gap "history absent" }
            }
            set tail [expr {$nsk ? "; $nsk revision(s) NOT VERIFIED -- [history_state]: $gap" : ""}]
            if {[llength $problems] == 0} {
                puts "ISSUE-STAMP: ok (0 problems$tail)"
                return 0
            }
            foreach p $problems { puts "ISSUE-STAMP: $p" }
            puts "ISSUE-STAMP: [llength $problems] problem(s)$tail"
            return 1
        }
        default {
            puts "usage: issue_stamp.tcl gate|report|selftest"
            return 2
        }
    }
}

## ⚠ DERIVED FROM THE FIXTURES, NEVER HAND-COUNTED.  This used to return a
## literal `lrepeat 16 x` with the arithmetic "5 good + 10 bad + 1 round-trip"
## in a comment beside it -- a hand-maintained mirror of a number that lives
## somewhere else, which is the defect class this entire batch is about, sitting
## inside the checker built to treat it.  It would have gone stale the moment
## anybody added a fixture, and the gate would have gone on printing a confident
## wrong count.  `selftest` is pure string work with no exec, so re-running it
## here to take the number from the artefact costs nothing.
proc istamp::selftest_case_names {} {
    variable selftest_n
    selftest
    return [lrepeat $selftest_n x]
}

if {![info exists ::ISSUE_STAMP_LIB]} {
    exit [istamp::main $argv]
}
istamp::init
