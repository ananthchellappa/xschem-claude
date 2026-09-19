# S1 verification: two refuters (workflow wf_704cbd18-d5d)

Both returned **refuted=false**. Their problems are copied verbatim below; S1-fix acts on them.

## lens: reproduce, refuted=False

### reasoning

S1's claims reproduce exactly on shapes I built myself from the working-tree diff (md5 cd9b06b6 / 618b0bab, the same as the main tree). All MEASURED:
- Every stranger shape is green, on the tclsh, xschem and T1-style arms.
- Skip counts are exactly as claimed: 0 in full clones, 2 in shallow, 5 in the export.
- The skip path is never taken in a full clone.
- The checker goes RED on six planted genuine defects in a full clone.
- Three independent sabotages of the skip logic all go red.
- Full T1 runs in three shapes score test_issue_stamp at 0.
- I also tried to break it with a space-and-capitals name, a `[`/`$`/`#`/`%` name, a worktree, a worktree of a shallow clone, --separate-git-dir, a blob:none partial clone (online and with its remote gone), a symlinked path, a foreign cwd, two concurrent runs, and an export with no git on PATH. All green.
So Item 1's done-when holds, and I do not refute the claims.

I did find one NEW defect that the fix itself introduces. The driver should get it corrected before committing (a one-line change; problem 1).
- The H-row fixture builder runs `git init/add/commit/clone` and inherits the caller's GIT_* environment.
- With GIT_DIR exported, the suite committed c1 and c2 onto the branch of the repo under test.
- Run from a pre-commit hook during `git commit -a`, it wrote a.txt into the user's index.lock and aborted the user's commit. The pre-fix suite in the same hook let the commit through, and the CLI stays safe there.

Three further residuals are real limits, not regressions (problems 2-4).

### problems

* 1. MUST FIX BEFORE COMMIT: a new hazard introduced by the fix (MEASURED). The fixture builder runs `git init/add/commit/clone` with the caller's GIT_* environment inherited. The code is tests/headless/test_issue_stamp.tcl, proc istamp_hist_fixtures, `set out [exec timeout 60 sh -c $script sh $root 2>@1]`, where the script's `g()` pins only -c config.
- With GIT_DIR exported, the suite commits fixture commits c1 and c2 onto the branch of the repository under test.
- Run from a pre-commit hook during `git commit -a` or `git commit -- <paths>`, git passes an absolute GIT_INDEX_FILE. The fixture's `git add a.txt` then writes into the user's index.lock, the user's commit aborts with `error: invalid object ... for 'a.txt' / Error building trees`, and H1-H5 false-red.
- The pre-fix suite did no git writes and let the same commit through. The CLI gate is unaffected.
- The code comment 'Every knob that could make a fixture commit depend on the tester's own git configuration is pinned' overclaims.
- Remedy (INFERRED, one line): start the sh script with `unset $(git rev-parse --local-env-vars)`, or exec it under `env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY -u GIT_COMMON_DIR -u GIT_ALTERNATE_OBJECT_DIRECTORIES`. Red-first: the hookclone recipe in my evidence reproduces it.

* 2. Residual, not a regression (MEASURED): a ZIP or export that a stranger imports into a fresh repository (`git init && git add -A && git commit`) probes as `full`. D9 and D9h go RED (T1 would count 3), because 61af3692 is not in the new history. This is the same principle as the batch's three shapes ('never report a failure because the history is not present'), but the probe cannot see it. A positive-evidence remedy to consider (INFERRED): a stamp dated D cannot resolve in a history whose root commit is newer than D. Otherwise record it as a known limit.

* 3. Residual, not a regression (MEASURED): in the `unreadable` state the suite is red by design and also DIES mid-file at Q1. Triggers: git's dubious-ownership refusal (the common container-CI shape, simulated with GIT_TEST_ASSUME_DIFFERENT_OWNER=1), or git missing while .git is present. The cause is the uncaught `exec timeout 30 git -C $istamp::repo show ${REV}:tests/banner_rule.tcl` inside check_needs. The rows after Q1 (A, N, D9, H, H7) never run, and 7 istamp_<pid>_* scratch corpses are left behind. This contradicts check_needs' own comment ('a row that cannot run never half-runs and never dies'). The pre-fix suite died at S20 in the same shape. Remedy: catch the exec inside Q1 and make it a named FAIL.

* 4. Minor or declared limits (MEASURED):
- In shallow and export, every revision-level defect (a bogus tree=, a rotted quote=, a tree= that names a blob) is `NOT VERIFIED` with rc 0 rather than refused. This is by design and named per item, but T1's results.log carries none of it: summarize_all copies no `skip:` lines, as S1 noted.
- In an export with no git binary, the RESULT trailer says `10 skipped -- none: history absent` while 5 of those skips are 'git is not installed'. Cosmetic.

* 5. For the driver, outside Item 1 (MEASURED): PLAN's 'T1 green in a renamed clone and a shallow clone' is not literally achievable with a fresh HOME. Both T1s ended at counted_failures=8, all from four segfaulting suites (test_op_annot, test_ase_optier_0963, test_unused_attr_0970, test_auto_specialize_1201; the audit's F14). test_issue_stamp contributed 0 in every shape.

### real-home check

`md5sum -c --quiet .../scratchpad/xschem_manifest_fixes.md5` returned rc 0 both before and after all my work.
- Every xschem, tclsh and T1 run used HOME=/var/tmp/xschem_fixes/s1v_repro/homes/<tag>, with DISPLAY unset.
- For the three T1 runs, each scratch tree's tests/headless/devdisplay.sh was replaced by a stub that refuses start and reports status dead. The originals were restored afterwards. So no run probed, started, stopped or deleted a lock on the real :99.
- The only Xvfb alive afterwards is the pre-existing foreign pid 1209045 that S1 reported.
- ~/.claude/xschem_dev_display and ~/.claude/gui_test_gate were only listed, never written.
- The main tree was only read, by file:// clones and `git diff`/`git show`. Its git status and the two files' md5s are unchanged, and nothing was committed there.
- The hook and GIT_DIR experiments committed only inside the scratch clone /var/tmp/xschem_fixes/s1v_repro/hookclone.
- Nothing was written in ~/dev/xschem-op-wcard.
- The scratch directory is left in place for the driver.

## lens: code, refuted=False

### reasoning

I could not refute S1's fix against what Item 1 requires. I measured every required shape myself, on byte-identical copies of the fix (md5 cd9b06b6… and 618b0bab…, the same as S1's), with HOME set to a scratch home and DISPLAY unset.

- **Full-history clones: green, nothing skipped.** The suite gives ALL PASS (60 checks) in a full clone renamed `xschem`, a no-tags single-branch clone, a clone under a path containing a space and a `#`, a worktree of the full clone, and two partial clones (blob:none, and tree:0 with its remote made unreachable).
- **Shallow clones: green with 2 named skips.** A shallow clone, a worktree of it (absolute and relative gitdir), and a --separate-git-dir shallow clone all give 58 passed plus 2 skipped (G4, D9h).
- **Exports: green with named skips.** A `git archive` export gives 55 passed plus 5 skipped (S0, G4, Q1, Q2, D9h). The same export with no git on PATH gives 50 passed plus 10 skipped, the extra five being H1-H5.
- **The xschem arm agrees.** In the shallow clone and the export it prints the same RESULT lines, with rc 0 and `OVERALL: ok`.
- **The readers accept every green output.** `regression_case_failed` scores 0 and T1 would count 0 lines. full_audit.sh's own `classify` says PASS, and neither `is_skip` nor `has_failure` fires.
- **A genuine defect still turns a full clone red.** With a stamp naming a revision that does not exist (`tree=deadbee0`), a full clone goes red (CLI rc 1; D9 and D9h FAIL). A shallow clone or an export names it NOT VERIFIED and exits 0. S1 states that limit openly.

My own sabotages (below) fill the gaps in S1's red-first evidence. D9h, which S1 never saw fail, fails when a verified revision stops being counted, or when a skip is recorded for a revision that resolved. H6 alone catches the probe misreading only this tree as none, shallow or unreadable. H1 catches removal of the check for a tree that git resolves inside another repository. H5 catches unreadable failing open into a skip. H3 and H4 catch the quote skip being removed. So a skip cannot quietly hide a real defect in a full clone.

What I did find are conditional or latent defects outside the plan's listed shapes. The worst is new with this change: the H-fixture script runs `git init/add/commit` with whatever git environment it inherits. With GIT_DIR exported, it wrote two commits onto the checked-out branch of the repository GIT_DIR names. With an absolute GIT_INDEX_FILE, which git 2.53 exports to a pre-commit hook for `git commit -a`, it wrote a foreign entry into that index. Both are loud (H1-H5 fail) and need an unusual environment, but they are the first T1 suite to write commits. The fix is a one-line environment scrub, and it should land before commit.

### problems

* NEW WRITE HAZARD, MEASURED, should be fixed before commit. `test_issue_stamp.tcl` `proc istamp_hist_fixtures` runs `g init` / `g add` / `g commit` with the caller's git environment. With GIT_DIR exported, it wrote commits `1c597b17 c1` and `77985222 c2` onto the checked-out branch of the repository GIT_DIR names. With an absolute GIT_INDEX_FILE, which git 2.53 exports to a pre-commit hook for `git commit -a` or `git commit <path>` (measured), it added a foreign `a.txt` entry to that index (9116 → 9117 entries). Both runs are loud (H1-H5 FAIL), but the damage is done by then. The pre-fix suite made no git writes, and no other T1 suite commits. Fix: run the fixture `sh` with GIT_DIR, GIT_WORK_TREE, GIT_INDEX_FILE, GIT_OBJECT_DIRECTORY, GIT_ALTERNATE_OBJECT_DIRECTORIES and GIT_COMMON_DIR unset.

* DOC VS CODE, READ. `proc istamp::history_probe` returns `none` only if `![info exists ::env(GIT_DIR)]`. So with GIT_DIR set, git IS asked for a tree with no .git. That contradicts the header's 'none: git is NEVER asked, so a repository above an unpacked export cannot answer for it'.

* THE UNREADABLE STATE DIES INSTEAD OF REPORTING RED, MEASURED. With git absent from PATH in a clone, or with dubious ownership (the container-CI shape), S0, S15, S15c, S20b, B3 and G2 fail. Then `check_needs "Q1 …"`'s uncaught `exec timeout 30 git … show` kills the suite (test_issue_stamp.tcl line 721). There is no RESULT line, and D9, D9h, H6, H7 and the W rows never run. Seven `istamp_<pid>_*` corpses are left behind. T1 still counts it, because the banner is missing. The pre-fix suite died the same way at S20, so this is not a regression, but the receipt's 'every revision question goes red' is not what happens.

* UNCOVERED STRANGER SHAPE, MEASURED. A download or export re-initialised with `git init && git commit` (the same shape as a template or import) is classified `full`. D9 and D9h go red, and the CLI prints `10 problem(s)` with rc 1 (all `tree=61af3692 does not resolve`). That breaks the plan's principle (never red because the history is not present), but the shape is not one of the three listed in Done-when.

* FIXTURE BUILD NOT HERMETIC AGAINST GIT CONFIG, MEASURED. `protocol.file.allow=never` in global or system config gives H1-H5 FAIL, `FIXTURES NOT BUILT: fatal: transport 'file' not allowed`, in a full clone. The fixture's `g()` pins identity, signing, hooks and the default branch, but not the transport. Adding `-c protocol.file.allow=always` fixes it.

* SKIPS ARE INVISIBLE IN T1's VERDICT, READ. `summarize_all` copies neither `skip:` lines nor the RESULT trailer, so a shallow or export T1 verdict looks the same as a full one in results.log. S1 flagged this (§9.2) as outside its two files. It remains open for the driver.

* LATENT, MEASURED. In an offline blob:none partial clone the probe answers `full`. A valid `quote=` of an older revision then becomes a problem worded as rot ('git show … failed -- a quoted block that no longer matches its source…'). The real corpus has 0 quote= blocks today, so there is no current effect.

* MINOR, READ. In the export, gate rows G2, A3, N1 and N2 (which expect a pass), plus B3, A2 and A4, run with the fixed token tree=d64686a1. That revision question is skipped inside the gate, yet each row counts as a pass and never enters ::SKIPPED, so H7 cannot see these in-row skips. H2-H4 cover the same behaviour on fixture repositories, so no coverage is lost.

* MINOR, READ. `HAVE_GIT` is `exec timeout 30 git --version`. On a box without the `timeout` program, H1-H5 skip with the reason 'git is not installed', which is wrong. The suite's dependence on `timeout` (S20's driver exec) predates this change.

* CROSS-ITEM, INFERRED, for S2b. Item 2's throwaway HOME strips git's global config, including a CI job's safe.directory, from every suite's git calls. In a container checkout owned by another uid, the probe then goes unreadable and the suite hits problem 3 (six reds, then death at Q1).

### real-home check

`md5sum -c --quiet /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/xschem_manifest_fixes.md5` gave rc 0 before any work and rc 0 after all of it, so no real-HOME drift was detected and no /tmp/Xschem.log attribution was needed. Every tclsh, xschem and git run used HOME=/var/tmp/xschem_fixes/verify_s1_code/home with DISPLAY unset. The main tree's two fix files are unchanged (cd9b06b6… / 618b0bab…), HEAD is still 4b9565ad, and its tests/headless/.scratch holds no istamp_ dirs. I ran no devdisplay command, wrote nothing in ~/dev/xschem-op-wcard, ran no T1 and made no commits. The GIT_DIR and GIT_INDEX_FILE experiments pointed only at scratch copies (full_gitdir, full_idx). The scratch dir is left for the driver.


## S1-fix2 refuter (verbatim)

## refuted: True
## reasoning: S1-fix2 is refuted. Its claim that the new per-stamp date rule "is fail-closed on every shape measured" does not hold. It lets a planted bogus `tree=` pass in an ordinary full clone, which is the same state as the main tree. S1-fix's bytes turned that same plant red. So this is a new fail-open, in the one state that has to be strict.

I worked on byte-identical copies (issue_stamp.tcl 4f990c5e…, test_issue_stamp.tcl fc98eca4…; md5 checked on every run) under /var/tmp/xschem_fixes/s1fix2_verify/, with HOME set to scratch and DISPLAY unset.

**What reproduced (MEASURED)**
- **Main tree:** ALL PASS (67 checks) with 0 skips on the tclsh, xschem and T1-spelling arms. CLI `ok (0 problems)`, rc 0.
- **Full clones and worktree:** the renamed clone `xschem`, worktree `wt` and a clone under `pct%41dir` give 67/67.
- **Shallow:** 64 passed + 3 skipped (G4 D9h H9).
- **Export, export inside another repo, and `git init` (unborn):** 60 passed + 7 skipped each, every stamp named NOT VERIFIED.
- **Re-init committed today:** 66 passed + 1 skipped (D9h), with all 10 stamps named.
- **Genuine defects with honest dates:** red.
  - `tree=deadbee0`: red on D9 D9h H9, CLI rc 1.
  - A blob `tree=`, a rotted `quote=` and a new unstamped file: red on B1 D9 D9h H9, CLI `3 problem(s)`.
- **Rewritten shapes:** the root-author rewrite (dates kept), the squash onto origin/main and the backdated re-inits (2020-01-01 and 2026-09-10) are all red.
- **Corrupt shallow:** `unreadable`, red on D9 D9h H6 H9, and RESULT is reached.
- **Odd `.git` shapes** (an empty `.git` directory, a garbage gitfile, a gitfile pointing at nothing): each is `unreadable` and red, and RESULT is reached.
- **Unreadable file and read-only checkout:** `chmod 000` gives named reds B1 B4 D9. A read-only checkout gives 67/67 using a temp scratch root, with no leftovers.
- **Hermetic writes hold:**
  - GIT_DIR/GIT_INDEX_FILE pointed at a victim repo: its files-md5 was d714ba6c before and after.
  - GIT_DIR pointed at the tree under test: 5817 commits, 9123 index entries, files-md5 97771f99, all unchanged.
  - Pre-commit hook with `commit -a` (index.lock) and `commit -- README` (next-index lock): commit rc 0, index 9123→9123, and 0 fixture files in HEAD.
- **Sabotages:** `gti` turns H7 red and the non-strict compare turns G4 H11 red.

**What refutes it (MEASURED, red-first against S1-fix's bytes ab4e64ba/8069a362)**
1. **The stamp's own `stamped=` date is trusted as the evidence that exempts it.**
   - READ: `parse_stamp` checks only `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`, and `rev_verdict` skips whenever `begins > stamped`.
   - The main tree's history begins 2020-08-08, so any stamp dated before that has its revision skipped.
   - Planted in 0056 of a full clone: `tree=deadbee0 stamped=2016-09-17`, a one-digit typo of the real date.
     - tclsh and xschem arms: rc 0, ALL PASS (67 checks), 0 row skips, case_failed 0.
     - CLI: rc 0, `ok (0 problems; 1 revision(s) NOT VERIFIED)`.
     - S1-fix's bytes on the same plant: RED on D9 D9h H9, CLI rc 1.
   - `stamped=0000-00-00`, which is not a date at all, also gives CLI rc 0.
   - Adding a bogus `quote=deadbee1` to the same file: still ALL PASS 67.
   - With the quote in a different backdated file, the CLI stays at rc 0, and only the suite's D9h reddens, by accident.
   - H11's L1 case skips this on purpose. No row asserts that D9_PREDATES is empty in an ordinary clone; only a comment says it is.
2. **Graft and orphan: the checker's own run contradicts the rule's premise.**
   - `git replace --graft HEAD` in a full clone makes the checker say `history begins 2026-09-18`. In the same run it verifies nine stamps dated 2026-09-17 whose 61af3692 is still in the store.
   - A bogus `tree=deadbee0` with the genuine date `stamped=2026-09-17`: ALL PASS 67, CLI rc 0. S1-fix's bytes: RED, CLI rc 1.
   - A full clone plus `git checkout --orphan` with a commit today: the same planted bogus gives ALL PASS 67, CLI rc 0.
   - The receipt calls the orphan case "indistinguishable from a re-init by construction" (INFERRED). That is false:
     - the same run verified revisions stamped before `begins`;
     - other refs still reach the 2020 root;
     - the checker scrubs the caller's GIT_NO_REPLACE_OBJECTS, so it always honours replace refs.
   - Legacy `.git/info/grafts` fails closed: git's deprecation hint goes to stderr, and the tree reads `unreadable`.
3. **A rewritten history still goes green while verifying nothing, if the rewrite also moves the root's author date.** This is S1-fix's refutation class.
   - I changed only the root commit's author date to now, via fast-export and fast-import. Every SHA changed, and 5816 of the 5817 commits keep their 2020-2026 dates.
   - Result: `history begins 2026-09-18`, all 10 stamps NOT VERIFIED, D9h skipped, ALL PASS (66 + 1 skipped). A planted bogus `tree=` passes too.
   - The receipt declares only "a filter-repo that also moves author dates" (INFERRED). Moving one date is enough.
   - The checker already walks the ancestry, and reading the earliest author date across all of it costs 0.106 s on the main tree (measured).

**Secondary (fail-closed, and already present in S1-fix)**
- A deprecated option in the user's global gitconfig (`core.fsyncObjectFiles=true`) makes git print a warning on stderr. Tcl's exec treats any stderr output as a failure.
- The result in a pristine full clone:
  - the state is `unreadable`, and the stated cause is blank (`git cannot read it: `);
  - the CLI reports 10 false "does not resolve" problems;
  - the suite reports 14 FAILED.
- The receipt's hostile-config recipe had no setting that makes git warn, so this was never exercised.

**Suggested remedies (INFERRED)**
- Refuse any `stamped=` earlier than the convention's first day (2026-09-17), or not a real calendar date, as a malformed stamp.
- Take `begins` as the earliest author date across all of HEAD's ancestry and all refs, with `--no-replace-objects`.
- Void the date rule for a run in which any revision stamped before `begins` resolves.
- Add a row that plants a backdated bogus stamp in a full history and requires it to be red.
## problems:
  * FAIL-OPEN in the plain full state, new in S1-fix2 (MEASURED).
- In a full clone (history begins 2020-08-08, the same state as the main tree), 0056's stamp was changed to `tree=deadbee0 stamped=2016-09-17`, a one-digit typo of the real date.
- Suite: rc 0, ALL PASS (67 checks), 0 row skips, case_failed 0, on the tclsh and xschem arms.
- CLI: rc 0, `ISSUE-STAMP: ok (0 problems; 1 revision(s) NOT VERIFIED -- full: history begins 2020-08-08, after them)`.
- S1-fix's bytes on the same plant: rc 1, RED D9 D9h H9, CLI `1 problem(s)`.
- `stamped=0000-00-00` also gives CLI rc 0. parse_stamp only format-checks the date (READ).
- A bogus `quote=deadbee1` added to the same backdated file: still ALL PASS 67, CLI rc 0.
- Cause (READ): `rev_verdict` skips whenever `begins > stamped`, so the stamp's own unvalidated date is the evidence that exempts it.
- No row catches this. H11's L1 skips it on purpose, and the claim that D9_PREDATES is 'empty in every ordinary clone' is a comment, not an assertion.
- This contradicts the receipt's 'Every other unresolved revision stays red', 'fail-closed on every shape measured' and 'Genuine defects in a full clone are all RED'.
- Logs: /var/tmp/xschem_fixes/s1fix2_verify/logs/bd2016.*.log, bd0000.cli.log, bdboth.*.log, pre_bd2016.*.log.
  * FAIL-OPEN with replace-graft or an orphan branch, new in S1-fix2 (MEASURED).
- `git replace --graft HEAD` in a full clone makes the probe say `history begins 2026-09-18`. The same gate run verifies nine stamps dated 2026-09-17 (61af3692 is still in the store).
- A planted `tree=deadbee0 stamped=2026-09-17`, with the genuine date: ALL PASS 67, CLI rc 0.
- S1-fix's bytes with the same graft and plant: RED D9 D9h H9, CLI rc 1.
- A full clone plus `git checkout --orphan sq && git commit` today: the same planted bogus gives ALL PASS 67, CLI rc 0.
- The receipt calls the orphan squash 'indistinguishable from a re-init by construction' (tagged INFERRED). That is false in-repo:
  - the run itself verified revisions stamped before `begins`;
  - other refs reach the 2020 root.
- git_scrub removes the caller's GIT_NO_REPLACE_OBJECTS, so replace refs are always honoured (READ).
- Logs: graft_bogus.*, pre_graft_bogus.*, orphan_bogus.*.
  * FAIL-OPEN survives on a rewritten history that also moves the root's author date. This is the S1-fix refutation class, and the receipt names it more narrowly than it is (MEASURED).
- Fast-export/fast-import changing ONLY the root commit's author date to now. Every SHA changes, and 5816 of the 5817 commits keep their 2020-2026 author dates.
- Result: `history begins 2026-09-18`, all 10 real stamps NOT VERIFIED, D9h skipped, ALL PASS (66 checks, 1 skipped). CLI rc 0.
- A planted `tree=deadbee0 stamped=2026-09-17` also passes.
- The receipt declares only 'a filter-repo that also moves author dates' (INFERRED). A single date suffices, and the shape is not 're-created from scratch'.
- `git rev-list --format=%at HEAD` over the whole ancestry takes 0.106 s on the main tree. The earliest date across all commits would expose it (INFERRED remedy).
- Logs: rootdate.*, rootdate_bogus.*.
  * Receipt accuracy (MEASURED and READ).
- In the three fail-open shapes above, the RESULT trailer stays `ALL PASS (67 checks)`, with no count of the NOT VERIFIED revisions. It is identical to a pristine main tree.
- The per-stamp skip is named only in the body (`not verified: …`). A T1 results.log reader sees nothing.
- The trailer names the cause only when HLATE retires D9h.
  * Secondary, fail-closed, already present in S1-fix (MEASURED).
- A deprecated option in the user's global gitconfig (`[core] fsyncObjectFiles = true`) makes git print a warning to stderr. Tcl exec treats any stderr output as an error.
- In a pristine full clone:
  - the state becomes `unreadable`, with a blank cause (`git cannot read it: `);
  - the CLI reports `10 problem(s)`, each a false 'does not resolve';
  - the suite reports 14 FAILED (S0 S20c G2 Q1 Q2 A2 A3 A4 N1 N2 D9 D9h H6 H9).
- S1-fix's bytes give the same CLI result.
- The receipt's hostile-config recipe contained no warning-emitting setting, so 'hostile config ALL PASS' does not cover it.
- Logs: warncfg.*, pre_warncfg.cli.log.
  * Suggested remedies (INFERRED, for the driver):
- (a) parse_stamp refuses a `stamped=` earlier than the convention's first day (2026-09-17), or not a real calendar date. This closes problem 1 in every ordinary clone.
- (b) Compute `begins` from the earliest AUTHOR time over all of HEAD's ancestry and all refs (`rev-list --all`), under `git --no-replace-objects`. This closes problems 2 and 3.
- (c) Void the date rule for a gate run in which any revision stamped before `begins` resolved.
- (d) Add a row that plants a backdated bogus stamp in a full fixture history that also holds older commits, and requires it RED. Sabotage it by removing (a) or (b).
## real_home_check: `md5sum -c --quiet /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/xschem_manifest_fixes.md5` gave rc 0 before any work and rc 0 after all of it.

- **Real home:** `find ~/.xschem ~/.claude/xschem_dev_display ~/.claude/gui_test_gate -newer /var/tmp/xschem_fixes/s1fix2_verify/.marker_start` printed nothing. The same check on ~/dev/xschem-op-wcard (outside .git) printed nothing.
- **How runs were made:** every tclsh, xschem, CLI and git run used HOME=/var/tmp/xschem_fixes/s1fix2_verify/homes/<tag>, with DISPLAY and GIT_EDITOR unset and a timeout on every command.
- **Main tree:**
  - It was only read, plus suite and CLI runs with a scratch HOME.
  - Its two files are unchanged (4f990c5e… / fc98eca4…) and HEAD is still 733e03ad.
  - `git status` shows only the pre-existing entries.
  - tests/headless/.scratch holds 0 istamp_/drv_ entries, and there are 0 /tmp/istamp_* entries.
  - Nothing was committed, stashed, reset or checked out there.
- **Where git writes went:** every git write (clones, plants, replace refs, orphan commits, the hook recipe, the victim repo) went to scratch repos under /var/tmp/xschem_fixes/s1fix2_verify/shapes/.
- **Display and other trees:** :99 and devdisplay were not touched, and ~/dev/xschem-op-wcard was not written.
- **Processes:** none of mine is running; the only `ps` match was the checking shell itself.
- **Left for the driver:** shapes, logs and scripts (run.sh, mk.sh, mk2.sh) under /var/tmp/xschem_fixes/s1fix2_verify/. The planted defects are still in place in the scratch clones orphan, rootdate and graft.

## IMPL open_problems (S1-fix2 crew):
  * A history re-created from scratch after the stamps is indistinguishable from a re-init by construction. Examples: an orphan squash committed today, or a filter-repo that also moves dates. Its stamps are named NOT VERIFIED and the run is green. A forged root author date would do the same. INFERRED, not measured.
  * Redundant layers: in unborn_evidence the refs check and the objects check each hold alone, and so do core.excludesFile and `add -f`. MEASURED: removing either one alone stays green, removing both is red. So no row holds a single layer on its own.
  * GIT_ATTR_NOSYSTEM is set but unmeasured, because planting /etc/gitattributes needs root.
  * Carried over: summarize_all still drops `skip:` lines (D12, driver); the offline blob:none quote= limit is latent; HAVE_GIT still depends on the `timeout` binary.
  * Not verified by a full T1 run. Only the T1 spelling (`cd tests && ../src/xschem --nogui --pipe -q --script headless/test_issue_stamp.tcl`) was run, in every shape.

## S1-fix3 refuter (verbatim)

## refuted: True
## reasoning: S1-fix3 is refuted on fail-open, although almost every measurement it claims reproduces. The new hole is not in `full` or `unreadable`: those really never skip (MEASURED). It is in how the probe gets into `shallow`.

**The hole (MEASURED; READ at issue_stamp.tcl `history_probe` / `rev_verdict`).** The checker calls a tree `shallow` whenever `git rev-parse --is-shallow-repository` answers true. That flag belongs to the whole repository, not to HEAD. Any shallow boundary anywhere in the store, even one that is not in HEAD's ancestry, exempts every revision that does not resolve.

Two ordinary shapes do this:
- **The developer's own full clone after one routine command.** Take a full clone of 616110a6 and run `git fetch --depth 1 origin main`; a failed `git pull --depth 1 --ff-only origin fluid-editing` does the same. The repository becomes `shallow=true` permanently, with `.git/shallow` naming only main's new tip. HEAD's history is still 5818 commits back to 7fe79fb2, the same as the main tree.
- **A stranger's CI flow.** `git clone --depth 1 -b main`, then a plain `git fetch origin fluid-editing` and a checkout. HEAD's history is again complete: 5818 commits, root 7fe79fb2, and 61af3692 resolves.

In both shapes I planted 0056 `tree=deadbee0` and 0216 `tree=<blob sha>`. Results on the final bytes:
- tclsh, xschem and T1-spelling arms: rc 0, `RESULT: ALL PASS (68 checks, 3 skipped -- shallow: history absent)`, and `regression_case_failed` scores 0.
- CLI: `ok (0 problems; 2 revision(s) NOT VERIFIED -- shallow: history absent)`.

The same plants in a plain full clone give CLI rc 1 with 2 problems. The skip is named, but the name is false: it says "commits older than its depth are not in it" and "history absent" while every one of HEAD's commits is present. H6 does not catch it, because it reads the shallow file and agrees. H7 does not catch it, because shallow's skip set is the declared one. No H1 fixture has a shallow boundary off HEAD's path.

The probe already holds the proof. The walk's roots are {7fe79fb2}, none of them is a shallow boundary, and none of their stored objects has a parent. In a real `--depth 1` clone the root is the boundary.

This is not a regression: S1-fix2's bytes give the same CLI result on both shapes. But it is exactly what D14 forbids: "no exemption for a history that has commits … whatever the ancestry looks like". It is also what the header forbids: only positive evidence of absence may skip.

**What reproduces (MEASURED, final bytes 2c6436ef/bf814c4f, checked on every run):**
- Main tree: ALL PASS 71 with 0 skips on the tclsh, xschem and T1 arms; CLI ok.
- 71 checks, all green: full clone, worktree, pct%41dir, blob:none, graft, orphan, deep, shallow-since and deepened clones, and graft with `GIT_NO_REPLACE_OBJECTS=1` set by the caller.
- shallow: 68 + 3 named skips (G4 D9h H9).
- export, export inside another repo, `git init`, `git init` + `add`: 64 + 7 named skips.
- RED D9 D9h H9, with the NOTE where 7fe79fb2 is absent: re-init today, re-init backdated to 2020, root-author rewrite, root-date rewrite, squash onto origin/main (no NOTE there).
- Corrupt shallow: unreadable, red D9 D9h H6 H9, RESULT reached.
- An uncommitted orphan branch in a repo with history: unreadable, red S0 H6, whether or not refs remain.
- Planted defects in a full clone are each RED: bd2016, 0000-00-00, blob `tree=`, rotted `quote=`, unstamped file.
- S1-fix2's bytes, for contrast: bd2016 and 0000 are green, and the warning config reads unreadable with a blank cause.
- Warning config and `GIT_TRACE=2`: ALL PASS 71.
- Dubious ownership: 14 FAILED, RESULT reached. No git on PATH: 14 FAILED + 13 skipped.
- `chmod 000` on an issue file: red B1 B4 D9. Read-only checkout: 71 on two arms. `TMPDIR=/proc`: red X0.
- Hermetic writes: a victim repository and the tree under test are byte-identical before and after.
- Sabotages: full_skips turns G4 H2 H5 H8 H11 H13 H14 red; removing `lacks_upstream` turns only H14 red.
- Every run: corpses 0→0.
## problems:
  * FAIL-OPEN on a complete HEAD history, pre-existing but inside D14's class (MEASURED). A full clone of 616110a6 plus one `git fetch --depth 1 origin main` (shape /var/tmp/xschem_fixes/s1fix3_verify/shapes/fetchd) has git's shallow flag set by main's tip (75bd6944), which is not an ancestor of HEAD. HEAD's history is complete: 5818 commits, root 7fe79fb2.
- A failed `git pull --depth 1 --ff-only origin fluid-editing` leaves the same state (shapes/selfdepth).
- Planted `tree=deadbee0` in 0056 and a blob `tree=8ccb7c22` in 0216. tclsh, xschem and T1 arms: rc 0, `RESULT: ALL PASS (68 checks, 3 skipped -- shallow: history absent)`, case_failed 0. CLI: `ok (0 problems; 2 revision(s) NOT VERIFIED -- shallow: history absent)`.
- The same plants in a plain full clone: CLI rc 1, 2 problems.
- S1-fix2's bytes are identical here (fetchd_pre), so this is not a regression.
- The stated reason ('commits older than its depth are not in it') is false.
- H6 agrees, because it reads the shallow file. H7 agrees, because this is shallow's declared skip set. No H1 fixture has a boundary off HEAD's path.
  * The same FAIL-OPEN in a stranger's CI flow (MEASURED, shapes/ciflow): `git clone --depth 1 -b main`, then a plain `git fetch origin fluid-editing` and `git checkout -b fluid-editing FETCH_HEAD`.
- The shallow file is {052b29f1}, off HEAD's path. HEAD's walk is 5818 commits, root 7fe79fb2, and 61af3692 is present.
- A bogus `tree=` plus a blob `tree=` give ALL PASS 68 + 3 skipped on tclsh, xschem and T1, and CLI rc 0.
- An empty `.git/shallow` in a full clone (contrived) does the same (shapes/eshallow).
  * Remedy (INFERRED from MEASURED discriminators). Stay `shallow` only when a root from HEAD's `--no-replace-objects` walk is itself a shallow boundary: roots ∩ the shallow file ≠ ∅, or the root's stored object carries a `parent` line. Otherwise the probe is `full`.
- Measured: fetchd, ciflow and eshallow have 0 roots that are boundaries and 0 with a parent; a real `--depth 1` clone has 1 and 1.
- Alternative, one exec: `git --shallow-file '' --no-replace-objects rev-list --max-parents=0 HEAD` succeeds in fetchd and selfdepth and fails in a real shallow clone. It uses an internal git option.
- Add an H1/H13 fixture that holds a shallow boundary off HEAD's path, with a planted bogus stamp that must be RED.
  * Minor misclassification (MEASURED): `.git` as a dangling symlink (shapes/dangling) reads `none -- no .git in this tree`, which is false. Result: 64 + 7 named skips, and a bogus `tree=` passes.
- The header says anything not positively established lands in `unreadable`. `file exists` follows the symlink, so a broken one reads as absent.
  * Genuine defect green in the author's own full clone, pre-existing and in the design (MEASURED, shapes/amend). A stamp naming a commit that no ref reaches passes: `commit --allow-empty`, then `reset --soft HEAD~1`, then `tree=` set to that commit.
- Author's clone: CLI rc 0 `ok`.
- After committing the stamp, a fresh clone of that repo is RED (1 problem). T1 would then count 3 for every stranger.
- `rev_exists`, H9 and D9h all use `cat-file -e`, which checks only the local store. The author's pre-commit gate is exactly where this should be caught, and it is not.
  * Argument injection writes a file during validation, pre-existing (MEASURED). `quote=` has no format check, and `quote_holds` runs `git show ${rev}:${path}`.
- An issue block of the form ```` ```c quote=--output=<scratch>/pwned path=x ```` made the gate write `<scratch>/pwned:x`: 21181 bytes, the `git show HEAD` output.
- The gate then reported it red. The write is already done by that point, and D9 runs this over the real corpus in T1.
- This contradicts 'no way to express anything but a grep'. Remedy (INFERRED): validate `quote=` like `tree=` (7-40 hex with at least one a-f), or pass `--end-of-options`.
  * Rotted quotes that pass silently, pre-existing parser scope (MEASURED). In a full clone, a `quote=61af3692 path=src/xschem.h` block with text that is not in that file gives CLI rc 0 `ok (0 problems)`, with no NOT VERIFIED line, in three forms:
- an indented fence (2 spaces, which CommonMark renders as a code block);
- a `~~~` fence;
- an unclosed fence at the end of the file.
The same block in a column-0 fence is red.
  * Accuracy of the receipt: it says 'Green with named skips only: shallow (G4 D9h H9)' and that `full` and `unreadable` never skip. Both statements are true, but the shallow classification is repository-wide while the question is about HEAD. So the named skip can sit on a complete history, and its RESULT trailer then asserts 'history absent' falsely.
## real_home_check: `md5sum -c --quiet /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/xschem_manifest_fixes.md5` gave rc 0 before any work and rc 0 after all of it.

**Real home.** `find ~/.xschem ~/.claude/xschem_dev_display ~/.claude/gui_test_gate -newer /var/tmp/xschem_fixes/s1fix3_verify/.marker_start` printed nothing. The same check on ~/dev/xschem-op-wcard, excluding .git, printed nothing.

**How runs were made.** Every tclsh, xschem, CLI and T1-spelling run used HOME=/var/tmp/xschem_fixes/s1fix3_verify/homes/<tag>, with DISPLAY and GIT_EDITOR unset, and ran under `timeout`.

**Main tree.**
- It was only read, plus suite and CLI runs with a scratch HOME.
- The two files are unchanged (2c6436ef… / bf814c4f…) and HEAD is still 616110a6.
- `git status` shows only the pre-existing entries.
- tests/headless/.scratch holds 0 istamp_/drv_ entries, and /tmp holds 0 istamp_*.
- Nothing was committed, stashed, reset or checked out there.

**Where git writes went.** Every git write went to scratch repositories under /var/tmp/xschem_fixes/s1fix3_verify/shapes/. That includes the bare mirrors (mirror.git, and mirror2.git with one extra commit each on main and fluid-editing), the plants, the amend commit, and the injection test's file `/var/tmp/xschem_fixes/s1fix3_verify/pwned:x`.

**Display and other crews.** `:99` and devdisplay were not touched. Other crews' r2i runs were seen in `ps` and left alone.

**Processes.** None of mine is running; the only `ps` match was the checking shell itself.

**Left for the driver.** Shapes, logs and scripts (run.sh, mk.sh, mkshapes.sh, plant.sh, clibatch.sh) are under /var/tmp/xschem_fixes/s1fix3_verify/. Every plant was restored, except the deliberately sabotaged copies sab1/sab2 and the committed stamp in amend.

## IMPL open_problems (S1-fix3 crew):
  * Redundant layer: D9h's skip-set column is not independently held. With the checker skipping and that column blanked, D9h stays red on its count column (9 of 10 verified). H13's skip column is the only assertion of (i) that nothing else duplicates.
  * A re-initialised download is RED by design, including in T1 (3 counted lines). The explanation is in the suite's `## history:` line and in D9's problem lines, but not in results.log, because summarize_all copies no suite body (D12).
  * A squash onto origin/main is red with no note, because that history does contain 7fe79fb2. A legacy .git/info/grafts file makes the NOTE appear on a green run, because git honours a grafts file even under --no-replace-objects. Both are wording only.
  * The suite costs about +6 s (≈19 s against ≈13 s).
  * Carried over: GIT_ATTR_NOSYSTEM is unmeasured (needs root); HAVE_GIT depends on `timeout`; the offline blob:none quote= limit is latent; summarize_all drops `skip:` lines.

## S1-fix4 refuter (verbatim)

## refuted: True
## reasoning: S1-fix4 is refuted. Everything it claims about git reproduces, but the checker still hands corpus text to a pipeline that can write files and run programs, and it still fails open in a full clone.

**The hole: the `assert=` grep exec** (READ at issue_stamp.tcl:1131, `exec timeout $t_grep /usr/bin/grep -rn -- $pat $target`).
- Tcl's `exec` treats any word beginning with `>`, `2>`, `<` or `|` as a redirection or a pipe, whether or not it follows `--`.
- `pat=` is one whitespace-free token taken from the issue file, so it can be exactly such a word.
- The receipt's argument table says the grep exec is safe because "assert_eval passes pat= after --". The spec (issue_stamp.md:286-288) promises "no shell and no interpolation". Measured, neither holds.
- The path is live in T1 today. 1219 is stamped (`tree=61af3692`) and carries an `assert=absent pat=SABOTAGE path=src state=broken` block, so every T1 run's D9 goes through this exec over the real corpus.
- It predates the batch: HEAD caa110ba has the same line at :462. That is exactly the status of the `quote=` hazard, which D15.3 fixed "even though it predates the batch".

MEASURED, each plant in one issue file of a scratch full clone (`shapes/xschem`), with HOME=scratch and DISPLAY unset:
- **Truncation.** `pat=>` with `path=README` turns the checkout's tracked README from 1243 bytes to **0 bytes**. The same happens on the CLI, the tclsh arm and the T1 spelling. The row goes red (D9) only after the write has happened.
- **Overwrite.** `pat=2>` with `path=README` replaces README with grep's 83-byte usage text.
- **Silent write.** `pat=>/var/tmp/.../pwned` writes a file outside the repository. The run stays **green**: CLI `ok (0 problems)`, and the suite gives `RESULT: ALL PASS (76 checks)`, rc 0, case_failed 0, on tclsh and T1.
- **A program runs.** `pat=|` with `path=mark_exec.sh` runs that script, which wrote its marker file. `path=../../../../../../usr/bin/id` also executes.
- **Fail-open, plausibly by accident.** `assert=absent pat=2>/dev/null path=src/xschem.tcl state=holds` is false, since the file has 4 occurrences. It still passes: CLI ok, ALL PASS 76. The control spelling `pat=/dev/null` is red (7 hits). With `pat=2>&1`, the T1 spelling gives ALL PASS 76 and leaves an untracked `tests/&1` in the checkout.

**Second fail-open: D15's own class, with the boundary ON HEAD's path.**
- In the developer's own full clone, one `git fetch --depth 1 origin fluid-editing` with nothing new writes HEAD (caa110ba) into `.git/shallow`.
- The same happens when the fetched ref is an ancestor. The fdanc shape uses 634b0cec, which is the main tree's `origin/fluid-editing` today, behind the local branch.
- The store still holds all 5819 commits: with the shallow file ignored (`GIT_SHALLOW_FILE=/dev/null/none`), git walks back to 7fe79fb2. A real `--depth 1` clone fails that walk with `Could not read`.
- The checker still says `shallow -- … commits older than that are not in it`, and all 10 stamps come back NOT VERIFIED.
- A planted `tree=deadbee0` plus a blob `tree=` gives CLI rc 0, and the suite gives `ALL PASS (73 checks, 3 skipped -- shallow: history absent)` on tclsh and T1.
- This follows D15.1's wording ("its stored object carries a parent line"). But the skip's reason is false, which is exactly what D15 was written to stop, and one exec can tell the two states apart.

**Two parser silent passes (D15.5).**
- A 4-backtick quote fence with an inner ``` line. Only the text before the inner line is checked, so a rotted line after it passes (CLI ok). markdown-it in CommonMark mode renders that line inside the quote block. The 3-backtick control is red.
- `__STAMP:__`, `<strong>STAMP:</strong>` and `<b>STAMP:</b>` naming `tree=deadbee0` in a grandfathered file each give CLI ok. markdown-it renders them to the same HTML as `**STAMP:**`.

**What reproduces (MEASURED, final bytes 6f649911/41adf733):**
- Main tree: ALL PASS (76 checks) with 0 skips on tclsh, xschem and T1, at 29.0-29.1 s. CLI ok (0 problems).
- Full clone `xschem` and worktree `wt`: 76.
- `--depth 1`: 73 + 3 skipped (G4 D9h H9).
- Export, and an export inside another repository: 69 + 7 skipped.
- Unborn: 69 + 7 skipped.
- `--shallow-since`, `--shallow-exclude` and `--deepen`: shallow with named skips; 61af3692 verified; plants NOT VERIFIED by name.
- `--unshallow`: full, and the plants are RED.
- fetchd (a boundary off HEAD's path): full, RED with 2 problems.
- Dangling `.git`: unreadable, 10 problems.
- Amend: RED, "NOT in HEAD's history".
- The `quote=` injection is closed. `--output=`, `>` and `|` values are each refused by name, and no file is written.
- Corpses 0→0 on every run.
## problems:
  * WRITE HAZARD and PROGRAM EXECUTION through assert= pat= (MEASURED). This is the same class as D15.3, which covered only git.
- issue_stamp.tcl:1131 runs `exec timeout $t_grep /usr/bin/grep -rn -- $pat $target`. Tcl exec parses a word beginning with `>`, `2>`, `<` or `|` as a redirection or pipe, and grep's `--` does not stop it.
- `pat=>` with `path=README`: README 1243 → 0 bytes, on the CLI, the tclsh arm and the T1 spelling.
- `pat=2>` with `path=README`: README overwritten with 83 bytes of grep usage.
- `pat=|` with `path=mark_exec.sh`: the script ran and wrote its marker. `path=../../../../../../usr/bin/id` also executes.
- Live in T1: 1219 is stamped and carries an assert= block, so D9 runs this exec over the real corpus every run.
- It predates the batch (HEAD caa110ba:462, and the same line in S1-fix3's bytes).
- The receipt's exec table claims `assert_eval passes pat= after --` as protection. The spec (issue_stamp.md:286-288) promises no shell.
- Logs: /var/tmp/xschem_fixes/s1fix4_verify/logs/runs/pattrunc.{tclsh,t1}.log, patpipe.cli.log, patpipe2.cli.log.
- Remedy (INFERRED): pass the pattern as one `--regexp=$pat` word, which Tcl never parses as a redirection. Confine path= to repo-relative with no `..`. Add a row that plants `pat=>`, `pat=|` and `pat=2>` and asserts nothing is written or run.
  * FAIL-OPEN in a FULL clone through the same exec (MEASURED).
- Plant: `assert=absent pat=2>/dev/null path=src/xschem.tcl state=holds`. It is false: xschem.tcl has 4 occurrences.
- Result: CLI `ok (0 problems)`; suite `RESULT: ALL PASS (76 checks)`, rc 0.
- Control `pat=/dev/null`: RED, `the file states this assertion HOLDS and it does not (7 hits …)`.
- `pat=>/var/tmp/…/pwned` wrote a file outside the repository with ALL PASS 76, rc 0, case_failed 0, on the tclsh and T1 arms.
- `pat=2>&1` under the T1 spelling: ALL PASS 76, and an untracked `tests/&1` was left in the checkout (a write outside the suite's scratch).
- Logs: devnull.{cli,tclsh}.log, devnullctl.cli.log, patsilent.{tclsh,t1}.log, amp1.t1.log.
  * FAIL-OPEN, D15's class, with the boundary ON HEAD's path while the store is complete (MEASURED).
- Shape fdself: a full clone plus `git fetch --depth 1 origin fluid-editing` with nothing new. `.git/shallow` names caa110ba (HEAD itself), and HEAD's walk becomes 1 commit.
- Shape fdanc: a fetch of an ancestor ref, 634b0cec. That is the main tree's own origin/fluid-editing today, behind the local branch. HEAD's walk becomes 7 commits.
- In both, the store holds all 5819 commits: `GIT_SHALLOW_FILE=/dev/null/none git rev-list --max-parents=0 HEAD` gives 7fe79fb2. The same command in a real --depth 1 clone gives `Could not read`.
- Checker: `shallow -- … commits older than that are not in it`; all 10 stamps NOT VERIFIED.
- With a planted bogus `tree=deadbee0` and blob `tree=8ccb7c22`: CLI rc 0 `ok (0 problems; 10 revision(s) NOT VERIFIED -- shallow: history absent)`; suite `RESULT: ALL PASS (73 checks, 3 skipped -- shallow: history absent)`, rc 0, case_failed 0, on tclsh and T1.
- This follows D15.1's letter (a root with a stored parent line), but the skip's stated reason is false, which is the refutation D15 answered.
- Remedy (INFERRED): one walk with the shallow file disabled. If it reaches a root with no parent, the state is full.
- Logs: fdself_bb.{tclsh,t1}.log, fdanc_bb.cli.log, fdself_clean.cli.log.
  * D15.5 silent pass: a 4-backtick quote fence (MEASURED).
- Plant: ````c quote=61af3692 path=src/xschem.h / #define CADMAXHIER 40 / ``` / <rotted line> / ````.
- CLI `ok (0 problems)`. fence_scan closes at the inner ```, so only the prefix is verified, and the fence that reopens carries no quote, so stray_quotes stays silent.
- markdown-it (CommonMark) renders all three lines as the one quote block.
- The same rotted line in a 3-backtick fence is RED.
- Remedy (INFERRED): close only on a fence of the same character, at least as long as the opener.
- Logs: fence4.cli.log, fence3.cli.log.
  * D15.5 silent pass: markdown's other bold spellings of a stamp (MEASURED).
- Plant: `__STAMP:__`, `<strong>STAMP:</strong>` or `<b>STAMP:</b>`, each followed by `v1 claim=fixed tree=deadbee0 …`, on line 3 of grandfathered 0057.
- Each gives CLI `ok (0 problems)`.
- markdown-it renders `__STAMP:__` to the same `<strong>STAMP:</strong> <code>…</code>` HTML as `**STAMP:**`.
- stray_stamps matches only `**`. Log: bold.cli.log.
  * Minor (MEASURED): in every shallow state, a tree= that names an object present in the store but not a commit is skipped as 'shallow: beyond the depth?'.
- The example is 8ccb7c22 = HEAD:README; `git cat-file -t` says blob.
- `cat-file -e rev^{commit}` cannot tell 'absent' from 'present and the wrong type', so positive evidence of a defect is skipped.
- Measured in the real --depth 1 clone (d1) and in the fdself and fdanc shapes.
  * Reproduced as claimed (MEASURED):
- main tree 76/76 with 0 skips on tclsh, xschem and T1, and CLI ok;
- xschem and wt: 76;
- --depth 1: 73 + 3;
- export and outer/nested: 69 + 7; unborn: 69 + 7;
- fetchd: full and RED; dangling: unreadable with 10 problems; amend: RED;
- since, exclude and deepen: named skips; unshallow: full and RED on plants;
- quote= injection closed (3 named problems, 0 files written);
- corpses 0→0 on every run.
## real_home_check: `md5sum -c --quiet /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/xschem_manifest_fixes.md5` gave rc 0 before any work and rc 0 after all of it.

**Real home and other trees**
- `find /home/analog/.xschem /home/analog/.claude/xschem_dev_display /home/analog/.claude/gui_test_gate -newer /var/tmp/xschem_fixes/s1fix4_verify/.marker_start` printed nothing.
- The same check on ~/dev/xschem-op-wcard, excluding .git, printed nothing.

**How runs were made**
- Every tclsh, xschem, CLI and T1-spelling run used HOME=/var/tmp/xschem_fixes/s1fix4_verify/homes/<tag>, with DISPLAY and GIT_EDITOR unset, under `timeout`.
- Git writes used HOME=/var/tmp/xschem_fixes/s1fix4_verify/homes/git.

**Main tree**
- It was only read, plus suite and CLI runs with a scratch HOME.
- Both files are unchanged: 6f64991118c6407b43fdef2c852419e4 and 41adf73392b80a7517ce42c0440f0062.
- HEAD is still caa110ba, and `git status` shows only the pre-existing entries.
- tests/headless/.scratch is empty, /tmp holds 0 istamp_* entries, and there is no `tests/&1`.
- Nothing was committed, stashed, reset or checked out there.

**Where writes went**
- Every git write and every plant went to scratch repositories under /var/tmp/xschem_fixes/s1fix4_verify/shapes/ (mirror.git, xschem, wt, d1, fdanc, fdself, since, exclude, deepen, unshallow, export, outer, unborn, fetchd, dangling, amend).
- The truncated README and the `tests/&1` file were in the scratch clone and were restored or removed. The pwned_* markers were deleted.
- Plants deliberately left in place, all in scratch: fetchd (bogus + blob), dangling (bogus), and amend (the edited stamp).

**Display and processes**
- :99, devdisplay and ~/.claude/gui_test_gate were not touched.
- No process with a s1fix4_verify HOME is alive. I checked through /proc/<pid>/environ, not pgrep.

**Logs**
- /var/tmp/xschem_fixes/s1fix4_verify/logs/runs/<tag>.<arm>.log.
- Scripts: run.sh, inst.sh, plant.sh.

## IMPL deviations + open_problems (S1-fix4 crew):
  * Item 1: the boundary test is 'a root whose stored object has a parent line'. D15's 'listed in the shallow file' disjunct is dropped because it is measured fail-open: a depth that reaches the root lists the true root. Sabotage B2 (the disjunct added back) reddens H1 and H16.
  * The legacy .git/info/grafts file is switched off for every checker git call (GIT_GRAFT_FILE pointing at /dev/null/istamp-no-grafts). D15 does not ask for this, but item 4 needs 'history as stored'. It also removes S1-fix3's NOTE-on-a-green-run in the grafts shape.
  * The ancestor rule covers quote= as well as tree=. They share rev_verdict.
  * stray_quotes also runs on files with no stamp (grandfathered or new). It measures 0 lines today.
  * Verdicts changed in shapes already measured: the orphan squash goes from green to RED (D9 D9h H9, D15.4's case); corrupt shallow goes from 4 to 12 reds (unreadable, noanswer); a dangling .git goes from none to unreadable.
  * The first red-first pass ran on intermediate bytes 19b97094 / ae6da854, which differ in wording and a caught census only. Every final-bytes half was re-run on the frozen bytes.
  * The first clean shallow run was mistakenly run in parallel with a planted run on the same shape. Those rows were discarded and re-run alone.
  * The xschem and T1 arms in the shapes use the main tree's src/xschem, as S1-fix3's refuter did, not a per-shape build.
  * Redundant layer I4: --end-of-options on rev_exists and rev_is_ancestor is not held alone by any row. The grammar blocks first, and neither command has an option that writes. Only quote_holds' lock is held alone (H17).
  * Two fail-closed branches are exercised by no row: noanswer (the revision resolves and merge-base errors, seen only in corrupt shallow) and a shallow_boundaries failure (goes to unreadable).
  * assert= path= is not confined to the repository: grep reads outside it on an absolute path. It is read-only and outside D15's scope.
  * /usr/bin/timeout is uutils coreutils 0.8.0, a flat 100 ms per exec. It causes this suite's +10 s and taxes every suite in the tree. For the driver.
  * A real shallow clone still reports revision-level defects as NOT VERIFIED (the stated limit). Fixture rows prove the refusal in every shape.
  * Carried over: summarize_all drops skip: lines (D12); GIT_ATTR_NOSYSTEM is unmeasured; HAVE_GIT depends on timeout; the offline blob:none quote= limit is latent.

## S1-fix5 refuter (verbatim)

## refuted: True
## reasoning: S1-fix5 is refuted on fail-open. Its exec and git claims reproduce. But three planted genuine defects pass the CLI, the tclsh arm and the T1 spelling together (MEASURED), and one of the three is a regression that S1-fix5's own Tcl scan introduced.

**What reproduces (MEASURED, final bytes 05e284e3/5a36d2df, HOME=scratch, DISPLAY unset)**
- Main tree: ALL PASS (83 checks) on the tclsh, xschem and T1 arms, 0 skips; CLI `ok (0 problems)`; `self-test PASSED (50 parser cases)`.
- Every earlier recipe is closed. `pat=` values `>`, `2>`, `|`, `>file`, `2>&1`, `<` and `&`, `quote=--output=`, and path= given as absolute, `..`, a link out, or starting with `-` were each tried. README stayed byte-identical, no marker was written and no `&1` appeared. The false `2>/dev/null` assertion is RED.
- Shallow family:
  - fdself, fdanc, fetchd, ciflow, eshallow, fdself+`--deepen 5`, a merge of a depth-1 fetch, unshallow and blob:none each read `full`, and bogus+blob plants are RED (fdself/fdanc: D9 D9h H9 on tclsh and T1).
  - d1, d20 and depth1+blob:none read `shallow` with named skips (80 + 3 skipped: G4 D9h H9), and the blob is RED.
- export and unborn: 76 + 7 named skips. dangling and corrupt shallow: `unreadable`, RED, RESULT reached. orphan: RED with the NOTE. amend: RED (not an ancestor). graft: RED. The stamped=2016 typo: RED.
- Parser: old and new over all 1047 numbered files give identical blocks and stray results.
- assert=: 99 of 99 literal pattern/path pairs match S1-fix4's grep exec in a scratch clone that carries the main tree's build products. 1219's block is 8 = 8.
- Corpses 0→0 on every run.

**How it fails**
1. **REGRESSION, new in S1-fix5.** The Tcl scan silently skips any file or directory whose name is not valid UTF-8. In `scan_dir`, `if {[catch {file lstat $p st}]} { continue }` fails because glob's decoded name does not round-trip under the default `C.UTF-8`.
   - Plant: a false `assert=absent pat=ZQXTOKEN path=src state=holds`, whose token exists only in `src/caf\xe9/note.txt`.
   - `grep -rn` finds 1 hit, and S1-fix4's bytes are RED. S1-fix5's bytes give `ok (0 problems)`.
   - Under `LANG=C` the scan counts 3 = 3, so the verdict depends on the locale.
2. **D16.5 is not met: stamps are not matched "by content".** Each of these, carrying `tree=deadbee0` in grandfathered 0057, gives `ok (0 problems)`:
   - `**STAMP:**` with a leading NBSP (markdown-it renders HTML byte-identical to a real stamp);
   - the same with a leading zero-width space;
   - `<strong class="s">STAMP:</strong>` (the `<strong>` spelling D16.5 names, with an attribute);
   - a stamp in a table cell, a task list, a link, or `<u>`.

   A second, contradicting NBSP stamp in stamped 0056 also passes, although the spec says the checker refuses two stamps. This is the class S1-fix4 was refuted on. It is pre-existing: S1-fix4's bytes are also ok.
3. **Unread assert= blocks are neither evaluated nor named.** A false `assert=` gives `ok (0 problems)` in each of these places: a `~~~` fence, a 2-space indented fence, a blockquote, a list item, an unclosed fence, or an unstamped file. A `quote=` in the same list-item position is named, so only quote= gets the D15.5 treatment. Pre-existing.
4. **End to end.** Planting items 1, 2 (NBSP) and 3 (list item) together gives CLI ok, tclsh ALL PASS 83 and T1 ALL PASS 83, all rc 0 with case_failed 0 (`logs/e2e.out`).

**Lesser findings on (a)**
- An issue file that is a symbolic link is followed out of the checkout: its target is read and its stamp checked. A link to a FIFO hangs the gate, stopped only by my external timeout (rc 124).
- `md_strip` (added in S1-fix4) is quadratic in line length. It is a busy Tcl loop that neither `timeout` nor the watchdog can interrupt. Three lines of 50k `>` took the gate from 0.6 s to 19.2 s.
- pat= is now literal rather than a regular expression: 45 of 144 regex-special pattern/path pairs differ. The real corpus is unaffected; the spec does not say so yet.
## problems:
  * FAIL-OPEN REGRESSION introduced by S1-fix5 (MEASURED). assert_scan/scan_dir silently skips any file or directory whose name is not valid UTF-8 (READ: scan_dir `if {[catch {file lstat $p st}]} { continue }`). Under Tcl's utf-8 system encoding (LANG=C.UTF-8, this box's default) glob returns a decoded name that does not round-trip, and lstat says ENOENT (MEASURED: `could not read .../dirÿ: no such file or directory`). Scratch clone shapes/plant: a token only in `src/caf\xe9/note.txt`, plus `assert=absent pat=ZQXTOKEN path=src state=holds` in 1219. `grep -rn` finds 1 hit and S1-fix4's bytes are RED ('HOLDS and it does not (1 hits…)'). S1-fix5's bytes give `ISSUE-STAMP: ok (0 problems)`, and the skip is not named. Library test (encdir): C.UTF-8 counts 1 against grep's 3; LANG=C counts 3, so the verdict depends on the locale. This contradicts 'recursive the way grep -r was' and '84/84 identical'.
  * FAIL-OPEN: D16.5 'stray stamps recognised by content' is not met (MEASURED; pre-existing, also ok on S1-fix4's bytes). Each spelling below was planted as line 3 of grandfathered 0057 carrying `v1 claim=fixed tree=deadbee0 …`, and each gives CLI `ok (0 problems)`:
- NBSP+`**STAMP:**` (markdown-it CommonMark renders HTML byte-identical to a real stamp);
- ZWSP+`**STAMP:**`;
- `<strong class="s">STAMP:</strong>`, which is D16.5's own `<strong>` spelling with an attribute;
- `| **STAMP:** … |` (a table cell);
- `- [ ] **STAMP:**` (a task list);
- `[**STAMP:**](x)` (a link);
- `<u>STAMP:</u>`.
A library probe also finds `<span>`, `<mark>`, a code span, escaped `\*\*`, `~~` and a BOM prefix unflagged. A SECOND, contradicting NBSP stamp (claim=open open=3 tree=deadbee0) in stamped 0056 also gives ok (0 problems), although the spec says 'exactly one stamp per file … the checker refuses it'. Scripts: plant_stamp.sh, stray.tcl.
  * FAIL-OPEN: assert= blocks the parser does not read are neither evaluated nor named (MEASURED; pre-existing, same on S1-fix4's bytes). A FALSE `assert=absent pat=SABOTAGE path=src state=holds` (8 real hits) appended to stamped 1219 is RED in a column-0 fence (control). It gives `ok (0 problems)` in each of these places:
- a `~~~` fence;
- a 2-space indented fence;
- a blockquote fence;
- a fence in a list item;
- an unclosed fence;
- a column-0 fence in grandfathered 0057.
The same list-item position carrying `quote=` IS named ('a fence that is indented'), so D15.5's treatment covers quote= only. That is 'verifying less than every assertion without naming the skipped item'. The real corpus has only one assert= line (1219:72), so naming these would redden nothing today (INFERRED from grep). Script: plant_assert.sh.
  * END-TO-END FAIL-OPEN (MEASURED, logs/e2e.out). In one scratch clone, three genuine defects were planted at once:
- the NBSP stamp with a bogus tree= in 0057;
- the false SABOTAGE assert= in a list-item fence of 1219;
- the false ZQXTOKEN assert= whose only hit is in the non-UTF-8 directory.
Results: CLI rc 0 `ok (0 problems)`; tclsh rc 0 `RESULT: ALL PASS (83 checks)` with case_failed 0; T1 spelling rc 0 ALL PASS 83 with case_failed 0; corpses 0→0.
  * (a) File reads outside the checkout by corpus shape (MEASURED; pre-existing; outside D16.2's path= rule). read_file follows an issue file that is a symbolic link. `doc/claude/issues/1601-sym.md -> <scratch>/outside/outside.md` was read, and its stamp checked ('1601: tree=deadbee0 does not resolve'). A link to a FIFO blocked the gate in `open` (rc 124 only from my external `timeout 20`; the checker has no bound). git cannot store a FIFO, but it can store a link to one or to /dev/zero. /dev/zero was NOT run, for the host's safety; unbounded memory is INFERRED. Nothing is ever lstat-checked for issue files or the baseline.
  * (a) A CPU bomb driven by corpus text, uninterruptible (MEASURED). md_strip (added in S1-fix4 and kept) strips one container token per regexp call and copies the rest of the line each time, so its cost is quadratic:
- one line of N `>` followed by a stamp costs 69 ms at 5k, 270 ms at 10k, 971 ms at 20k and 3996 ms at 40k;
- with `- ` repeated, 40k costs 8475 ms;
- a 155 KB 0057 (three lines of 50k `>` plus 'stamp') took the CLI gate from 0.6 s to 19.2 s.
A 1 MB line would take about 40 min (INFERRED). It is a busy Tcl loop, which neither `timeout` nor the in-suite watchdog can interrupt (W13); only T1's 900 s per-case cap stops it. Today's longest corpus line is 1491 characters, so the effect is negligible now.
  * (c) Semantic drift in pat=, beyond the real corpus (MEASURED, diff_assert.tcl on a scratch clone with the main tree's src build products). Literal patterns (including ü, é, ELF and matches inside binaries): 99/99 identical, and 1219's block is `0 8` both old and new, so the brief's (c) criterion holds for today's corpus. With regex-special patterns (a.c, x*, ^#, $, [a], foo\|bar, \.), 45 of 144 pairs differ. Example: `assert=absent pat=foo\|bar state=holds` is RED on S1-fix4's bytes (593 hits in src/xschem.tcl) and GREEN on S1-fix5's (0). doc/claude/specs/issue_stamp.md §4 still does not say 'literal', and its example body is `grep -rn SABOTAGE src/`. The crew documented this deviation.
  * Reproduced as claimed (MEASURED):
- Main tree: tclsh, xschem and T1 each ALL PASS (83 checks) at about 41 s with 0 skips; CLI ok; 50 parser cases.
- Previous refuters' text recipes: nothing written or run, and RED where they should be (textplants.sh).
- Shallow family: fdself, fdanc, fetchd, ciflow, eshallow, fddeep, mshallow, unshallow and blobless are full, with bb RED (2 problems; D9 D9h H9 on the suite). d1, d20 and pshallow are shallow with 10 named NOT VERIFIED; bb there leaves the bogus stamp skipped by name and the blob RED; the suite gives 80 + 3 skipped (G4 D9h H9), and d1+bb gives D9 red.
- export and unborn: 76 + 7 skipped (S0 S20c G4 Q1 Q2 D9h H9) on tclsh and T1.
- dangling: 13 FAILED; corrupt shallow: 12 FAILED; RESULT reached in both.
- wt, weird path and graft: ALL PASS 83.
- amend: RED notancestor; bd2016 and 2025-12-31: RED; 0000-00-00: malformed.
- Parser diff (old against new) over 1047 files: 0 block, 0 stray-stamp and 0 stray-quote differences.
## real_home_check: `md5sum -c --quiet /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/xschem_manifest_fixes.md5` gave rc 0 before any work and rc 0 after all of it.

**Real home and other trees**
- `find /home/analog/.xschem /home/analog/.claude/xschem_dev_display /home/analog/.claude/gui_test_gate -newer /var/tmp/xschem_fixes/s1fix5_verify/marker_start` printed nothing.
- The same check on ~/dev/xschem-op-wcard, excluding .git, printed nothing.
- :99, devdisplay and the gui_test_gate were not touched.

**How runs were made**
- Every tclsh, xschem, CLI and T1-spelling run used HOME=/var/tmp/xschem_fixes/s1fix5_verify/homes/<tag>, with DISPLAY and GIT_EDITOR unset, and ran under `timeout`.
- Git writes used HOME=…/homes/git.

**Main tree**
- It was only read, plus clean suite and CLI runs (tclsh, xschem, T1 and CLI).
- No plant of any kind ran there.
- Its two files are unchanged: 05e284e38df36519b7f255a1a0394d21 and 5a36d2dfad4cc6a55852072ac7cfdc06.
- tests/headless/.scratch is empty, /tmp holds 0 istamp_* entries, and there is no `&1` or `tests/&1`.
- Nothing was committed, stashed, reset or checked out there. HEAD moved from 52453f1e to 4da72c24 during this session through another agent's commit, not mine.

**Where writes went**
- Every plant and every git write went to repositories under /var/tmp/xschem_fixes/s1fix5_verify/shapes/ (a mirror of the main tree plus clones: xschem, plant, built, fdself, fdanc, fetchd, eshallow, d1, d20, ciflow, unshallow, pshallow, blobless, fddeep, mshallow, dangling, export, unborn, amend, graft, orphan, cshallow, wt, and `we ird[x] %41`).
- The outside, encdir and markers directories are also under that scratch root.
- Every plant was restored; the plant clone was checked clean afterwards, and the café directory was removed.

**Processes**
- A /proc/*/environ scan found no live process with an s1fix5_verify HOME.
- Every background batch completed.

**Logs and scripts**
- Logs: /var/tmp/xschem_fixes/s1fix5_verify/logs/ (runs/<tag>.<arm>.log, batch1.out, batch2.out, e2e.out, diff_assert_literal.out).
- Scripts: run.sh, inst.sh, plant.sh, plant_stamp.sh, plant_assert.sh, textplants.sh, e2e.sh, mkshapes.sh, mkshapes2.sh, diff_assert.tcl, diff_parse.tcl, stray.tcl, quad.tcl, enc.tcl.

## IMPL deviations + open_problems (S1-fix5 crew):
  * pat= is a LITERAL string, not grep's basic regular expression. The spec calls it a token and the recipes had to be judged literally; literal matching also cannot hang the Tcl interpreter (backreference patterns can). The one real block (SABOTAGE) counts 8 either way. doc/claude/specs/issue_stamp.md section 4 should say 'literal' (not my file).
  * Binary files: a matching file that contains a NUL byte is unevaluable, by name. That preserves grep 3.12's measured verdict (it reports binary matches on stderr, which the old exec read as a failure). grep's locale-dependent encoding-error test is not reproduced.
  * Newly refused as named problems (fail-closed, none occur in the corpus): an empty pat=; a path= that is neither a file nor a directory (a FIFO would block); an absolute symlink target that reaches the checkout only through another link.
  * The path rule and the no-corpus-word-on-the-command-line rule were extended to quote=: its path= is shape-checked, and <rev>:<path> goes to cat-file --batch on stdin. A quote naming a directory is now 'not a file at that revision' (git show used to print a listing).
  * shallow requires two agreeing pieces of evidence: the walk with the shallow file disregarded exits 128, AND a boundary sits on HEAD's honoured walk. Any other outcome is unreadable.
  * H6's disk check now accepts full or shallow for any repository with a shallow file. The old 'HEAD is listed, so it is shallow' is exactly the fdself shape. H1 and H19 hold the probe on fixtures instead.
  * The 'names a blob/tree' wording applies in every state, not only shallow. Only the words change in full, where these were already RED; this is part of the +11 s.
  * Cost trims: H20 and Q7 use one gate run per corpus (hcorpus), and H19's fdanc half checks 3 stamps rather than the 7-stamp row, to bound cost.
  * The xschem and T1 arms in the shapes used the main tree's src/xschem (built 09-17), as S1-fix4 and its refuter did.
  * Redundant layer I2: removing rev_token from rev_exists stays green, because the gate grammar and --end-of-options still hold. The doubled lock is deliberate; no row holds it alone.
  * Branches no row exercises, all fail-closed (READ): the disregarding walk exiting other than 128 (-> unreadable); that walk failing with no boundary on HEAD's walk (-> unreadable); an empty pat= (refused).
  * No row can test the choice of the empty GIT_SHALLOW_FILE over /dev/null/none: they behave identically today (MEASURED). The choice rests on which way each fails.
  * Q6 makes its outside directory mode 000 for the row's length. A run killed mid-row leaves a corpse the sweep cannot delete (a leftover survives).
  * Suite cost is +11 s on T1 (~380 s). Restricting rev_type to the shallow state would save about 2-3 s at the price of the type-naming wording in full (INFERRED from the profile). This is the driver's call.
  * doc/claude/specs/issue_stamp.md does not state pat= semantics. It should say literal, with no special characters (outside my files).
  * Carried over: summarize_all drops skip: lines (D12); GIT_ATTR_NOSYSTEM is unmeasured; HAVE_GIT depends on timeout; quote_holds in an online blob:none clone may still lazily fetch the quoted blob (latent, 0 quote blocks in the corpus); uutils timeout costs 100 ms per exec.

## S1-fix6 refuter (verbatim)

## refuted: True
## reasoning: S1-fix6 is refuted. Every claim I re-ran reproduced, but I measured three kinds of in-scope failure.
- **(A) reads outside the checkout.** A committed `doc/claude/issues` link to a directory outside the checkout makes both the suite and `report` read the files there. The crew claimed exactly the opposite for both.
- **(B) honest mistakes pass green.** Three canonical-format mistakes pass on every arm: a multi-word `pat=`, a stamp missing its colon, and a new unstamped file whose number collides with a grandfathered one.
- **Further (A) and (C) edges.** A partial clone fetches from the network and writes into `.git`. There is no total CPU bound on `assert=` scans. A clone under a directory whose name is not valid UTF-8 is falsely red.

**What reproduces (MEASURED, final bytes 81b5885c/865d94a3, HOME=scratch, DISPLAY unset, every command under timeout)**
- **Main tree.** tclsh, xschem and T1 each give ALL PASS (87 checks) with 0 skip lines, about 41.7 s. The CLI gives `ok (0 problems)` with 62 parser cases. Under LANG=C, tclsh, T1 and CLI give the same.
- **Red-first on the mixed bytes** (final suite, S1-fix5 checker): 4 FAILED, exactly Q9 Q10 Q11 Q12. The got-values match the crew's, including `TIMED OUT: the gate blocked on a FIFO` and `SLOW: 58810 ms`.
- **rf6.sh, S1-fix5 bytes then final bytes.** Every row of the crew's table matches:
  - on S1-fix5: item 1 is ok under C.UTF-8 and RED under LANG=C; 7 unread assert= placements pass; the link out is read; the FIFO cases hit rc 124 at 20.1 s; the baseline link is ok; md_strip costs 24.2, 23.3 and 7.9 s;
  - on final: all of these are named, in 0.31-0.61 s.
- **rf6b.sh** matches the crew's results.
- **Earlier refuters' recipes.** textplants.sh leaves README unchanged, with 0 markers and no `&1`; `2>/dev/null` and `&` are RED. The S1-fix5 refuter's e2e gives CLI 2 problems and D9 red on tclsh and T1. Stamp near-misses (`<strong>`, `__STAMP:__`) are named.
- **Shapes, four arms each, corpses 0->0:**
  - d1: 84 passed, 3 skipped (G4 D9h H9);
  - export, nested export, unborn: 80 passed, 7 skipped;
  - full clone, wt, `we ird[x] %41`, `~root`, emoji path: ALL PASS 87;
  - café/xschem under LANG=C (tclsh and T1): ALL PASS 87.
- **Other checks.** GIT_DIR pointed at a victim repo leaves it byte-identical. Sabotage E1 reddens Q9 and R4 reddens Q11. md_strip is linear on 11 more adversarial shapes (2.4 MB in 10.6 ms). The Q12 gate itself takes about 10 ms. `report` with a FIFO issue file returns in 0.4 s.

**How it fails:** see problems. Logs are under /var/tmp/xschem_fixes/s1fix6_verify/logs/.
## problems:
  * (A) READS OUTSIDE THE CHECKOUT (MEASURED, contradicts the receipt). In scratch clone shapes/probe, doc/claude/issues was replaced by a symbolic link to a copy outside the checkout. The gate correctly answers CORPUS OUTSIDE THE CHECKOUT, but:
- **The suite reads the outside files.** B1 printed `got: 1 9997`. 9997 is an unstamped file that exists only outside. 9998, a stamped file that also exists only outside, was not listed, so its contents were read to find its stamp (logs/runs/suite_linkout.tclsh.log, RESULT 3 FAILED B1 D9 D9h).
- **`report` reads them too.** Its coordinate-citation grep went from 4689 to 9689: +5000, exactly the lines planted outside. It prints `issue files: 0` and names nothing.
- **READ, the cause.** Only `gate` asks issues_dir_problem. The suite's istamp_read_issue lstats the file, not the directory. report's `exec timeout 60 /usr/bin/grep -rnoE ... [file join $repo doc/claude/issues]` follows a symbolic link given on the command line.
- **Crew statements this contradicts:**
  - 'report obeys the same rule';
  - report's own comment: 'an advisory census must not read outside the checkout';
  - 'The suite's own corpus reads (B1, B4, the D9 census) now lstat first as well'.
- **Coverage.** No row exercises report: sabotage REP (report's not_regular check removed) still gives ALL PASS (87 checks).
  * (B) A FALSE assert= WITH A MULTI-WORD pat= PASSES ON EVERY ARM (MEASURED; also on S1-fix5 bytes, so pre-existing).
- **READ, the cause.** fence_scan keeps only `^[a-z]+=` tokens and silently drops every other word of a READ fence's info string. The stamp grammar, by contrast, refuses any token that is not key=value.
- **Plants in stamped 1219**, a column-0 closed backtick fence in a full clone:
  - `assert=absent pat="static int" path=src state=holds`: the phrase is on 463 lines of src by grep -rnF, and the gate says ok (0 problems). It evaluated the literal `"static` and dropped `int"`.
  - `assert=present pat=static nonexistent_zz_symbol path=src state=holds`: the phrase is on 0 lines, and the gate says ok, because it evaluated `static`.
- **Why it counts.** The spec §4 says pat= is 'one whitespace-free token', so this is a malformed block that is evaluated as a different, weaker claim, with no word said. It is a false assert= in the canonical format.
  * (B) A STAMP MISSING ITS COLON IS NOT NAMED (MEASURED). Line 3 of grandfathered 0057 was set to `**STAMP** `v1 claim=fixed tree=deadbee0 stamped=2026-09-17 fix=taken open=0``, and the CLI says ok (0 problems). The same happens with `STAMP `v1 ...``, `**Stamp** `v1 ...``, `**STAMP -**`, `**STAMP;**` and `**STAMP.**`. In the same position, `*STAMP:*`, `**STAMP :**`, ` **STAMP:**` and `## **STAMP:**` are named.
- **READ, the cause.** stamp_shaped requires `stamp[ \t]*:`, so the stamp's own `v1 body does not rescue a dropped colon.
- **Why it is in scope.** There is no invisible character, no HTML and no container here: it is a one-character typo of the canonical line. D18 B requires such near-misses to be named, just as `__STAMP:__` is. As written, the bogus tree= is never checked.
  * (B) A NEW UNSTAMPED ISSUE FILE UNDER A GRANDFATHERED NUMBER PASSES (MEASURED; pre-existing).
- **Plant.** `doc/claude/issues/1349-a-second-defect-under-a-colliding-number.md`, with no stamp. 1349 is in the baseline, and CLAUDE.md records 1349-1353 as real cross-clone number collisions.
- **Result.** CLI ok (0 problems). The control `1601-new-unstamped.md` is RED.
- **READ, the cause.** The gate and row B1 both grandfather by number (`dict exists $base $num`), so a colliding new file inherits the exemption. D18 B lists 'an unstamped new file' as a defect that must be RED.
- **Lesser, same class.** Near-miss names are never listed at all, so they pass ok: `1601_underscore-slug.md`, `1601.md`, `1601-x.MD`, `1601 space-slug.md`.
- **All at once, in shapes/probe2** (logs/e2e2.out): the collision, the two multi-word asserts, the colon-less stamp with tree=deadbee0 and the underscore file. CLI rc 0 `ok (0 problems)`; tclsh, xschem and T1 each rc 0, `ALL PASS (87 checks)`, case_failed 0.
  * (A) A PARTIAL CLONE FETCHES OVER THE REMOTE AND WRITES INTO .git (MEASURED).
- **Setup.** A blob:none clone of a file:// mirror with uploadpack.allowFilter. In 0056, tree= was set to the full 40-hex SHA of a blob absent locally (9ccdced1…, fluid-editing~300:src/xschem.tcl). A blob tree= is one of D18's honest mistakes.
- **Result.** The verdict is correct (RED, 'names a blob'). But GIT_TRACE (logs/trace_blob.log) shows the checker's git calls ran:
  - `git fetch origin --no-tags --filter=blob:none --stdin`;
  - `/bin/sh -c git-upload-pack …`;
  - `git index-pack --promisor`;
  - `git maintenance run --auto --no-quiet --detach`.
- **What it wrote.** A new pack appeared in the checkout's .git/objects/pack (8 to 12 files), and the blob is now present locally.
- **Typo'd full SHA.** It ran fetch and upload-pack twice (logs/trace_typo.log). With an https or ssh remote this is network I/O and a transport program started because of corpus text.
- **READ, the cause.** GIT_NO_LAZY_FETCH rides only on the `noshallow` walk, not on rev_exists, rev_type, rev_is_ancestor or quote_holds.
- **What the crew disclosed.** Only quote_holds, as 'latent'.
  * (A) NO TOTAL BOUND ON assert= SCANS: CORPUS TEXT BUYS MINUTES OF UNINTERRUPTIBLE CPU (MEASURED).
- **Plant.** 100 two-line fences `assert=absent pat=ZQXNOPE<i> path=. state=holds` appended to stamped 1219: +5.8 KB, 9.9 KB file.
- **Result.** CLI gate 211 s (1 block 2.7 s, 10 blocks 21.5 s; logs/cpu100.out).
- **READ, the cause.** t_scan bounds each scan at 60 s, nothing bounds how many there are, and each scan is a Tcl loop that neither `timeout` nor the W13 watchdog can interrupt. About 430 such blocks (~25 KB) would exceed T1's 900 s per-case cap.
- **Weight.** Cost is linear in the number of blocks, so under the crew's 'linear' criterion this is arguable. But it is more CPU per corpus byte than the md_strip case D18 fixed (155 KB for 19 s).
  * (C) A FULL CLONE UNDER A DIRECTORY WHOSE NAME IS NOT VALID UTF-8 IS FALSELY RED IN BOTH LOCALES (MEASURED, shapes/lat\xe9/xschem, logs/latin.out).
- **C.UTF-8.** The path does not round-trip. history reads `none` (a full clone called an export), and the CLI says BASELINE MISSING. The suite gives 9 FAILED (S20 S20b B1 A1 A2 A3 A4 Q11 D9) with 7 skipped.
- **LANG=C.** history is `unreadable`: this box's `timeout` (uutils 0.8.0) refuses non-UTF-8 argv with 'error: invalid UTF-8 was detected in one or more arguments'. The CLI gives 10 false 'does not resolve', and the suite 37 FAILED.
- **What the crew said.** They listed the C.UTF-8 case as unmeasured (INFERRED). The LANG=C / uutils cause is new.
- **Contrast and weight.** UTF-8 paths (café, 日本, emoji📁) are green on both locales. This is an exotic kind of 'renamed clone', so I weight it low.
## out_of_scope:
  * Deliberate-disguise stamps in grandfathered 0057 carrying tree=deadbee0 each give `ok (0 problems)` (MEASURED with the S1-fix5 refuter's plant_stamp.sh on the final bytes): an NBSP prefix, a ZWSP prefix, `<strong class="s">`, a table cell, a task list, a link and `<u>`. These are out of scope under D18.
  * The NBSP stamp in the S1-fix5 refuter's end-to-end plant is still not named. It is out of scope, and the other two plants in that e2e are now RED.
  * A UTF-8 BOM before `**STAMP:**`, an invisible character, was not measured. By READ, stamp_shaped would not see it. It is more likely an editor accident than a disguise, but D18's wording puts invisible characters out of scope.
  * Quoting a single-word pattern (`pat="SABOTAGE"` or pat=`SABOTAGE` with backticks) passes a false assertion (MEASURED: 0 literal hits against 8 unquoted). The spec now explicitly makes pat= literal, so the checker is correct to the spec. I do not count this. The multi-word case counts because a token is silently dropped.
## real_home_check: `md5sum -c --quiet /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/xschem_manifest_fixes.md5` gave rc 0 before any work and rc 0 after all of it.

**Real home, other trees and processes**
- `find /home/analog/.xschem /home/analog/.claude/xschem_dev_display /home/analog/.claude/gui_test_gate -newer /var/tmp/xschem_fixes/s1fix6_verify/marker_start` printed nothing. The same find over ~/dev/xschem-op-wcard (excluding .git) printed nothing.
- :99, devdisplay and the gui_test_gate were not touched.
- A /proc/*/environ scan found 0 live processes with an s1fix6_verify HOME.
- There are no FIFOs under my scratch, and /tmp holds 0 istamp_* entries.

**Main tree**
- It was only read, plus clean runs: tclsh, xschem, T1 and CLI, and LANG=C tclsh, T1 and CLI, all with HOME=scratch and DISPLAY unset.
- HEAD is still 9fbc6fd9. Its three files are unchanged (81b5885c / 865d94a3 / 03881750), and git status is as at the start.
- tests/headless/.scratch is empty, and there is no `&1`.
- No plant of any kind ran there, and nothing was committed, stashed, reset or checked out.

**Where writes went.** Every plant, link, FIFO, non-UTF-8 name and git write went to clones of my own mirror under /var/tmp/xschem_fixes/s1fix6_verify/shapes. Every plant was restored, and each clone was checked clean afterwards.

**My error.** A script adapted with a bad sed left W pointing at the crew's directory. Before I killed it, it overwrote crew evidence in /var/tmp/xschem_fixes/s1fix6/logs/:
- `rf6_pre.out`, which now holds 14 lines of my partial run;
- 9 files in `runs/`: `rf6_pre_nonutf8_{C.UTF-8,C}.cli.log` and `rf6_pre_assert_{col0,tilde,indent2,bq,list,unclosed,grandf}.cli.log`.

All plants from that run landed in my own clone. The rewritten content is the same measurement on S1-fix5 bytes, and it matches the crew's table. The original bytes cannot be recovered. I removed the empty `s1fix6/outside_pre` directory the run had created and touched nothing else of the crew's.

## IMPL deviations + open_problems (S1-fix6 crew):
  * istamp_file_url in the suite now takes a path's bytes through the system encoding instead of utf-8. This is outside D18's list. It fixes a false red of 19 rows (18 H rows and Q7) under LANG=C in a clone under a UTF-8 'café/' directory. The red was already present, identically, on S1-fix5's bytes. Sabotage U1 holds the fix.
  * The corpus directory is confined too (issues_dir_problem). A committed link at doc/claude/issues that leads out of the checkout gives 'CORPUS OUTSIDE THE CHECKOUT' and nothing in it is read. The check applies only to the checkout's own corpus; a link that stays inside is followed. Q11, R4 and C2 hold it.
  * A symlink issue file that points inside the checkout is also refused, because the rule is about what the entry is. The real corpus has 0 symlinked issue files.
  * An issue file whose name is not valid UTF-8 is named in both locales, but differently: 'cannot be looked at' under C.UTF-8, and read as a new unstamped file under LANG=C. Both are fail-closed. Only the assert= scan was made byte-exact, as item 1 asked.
  * The unstamped wording reads 'an assert= the parser does not read (in a file with no **STAMP:** line, where no assert= is ever evaluated)'. This is the task's 'assert= in a file with no stamp is not evaluated', written in the same form as quote='s existing sentence.
  * report also stops opening non-regular files and reports the state of the baseline.
  * Q9 emulates both locales in process by forcing `encoding system`, re-reading the checker's root as each locale would decode it. The real-locale evidence is separate: runs under LANG=C LC_ALL=C.
  * Slip, fixed before freeze: the Edit tool turned my é escape into a literal é in Q9's code, which reds Q9 under LANG=C. It is now an ASCII escape, and non-ASCII bytes remain only on comment lines.
  * Concurrency slips, each re-measured: (a) the two locales ran concurrently in the same café clone, which produced a spurious '26 corpses'; (b) misc.sh and defects.sh first ran concurrently in the same xschem clone, and both were re-run solo in separate clones with identical verdicts; (c) the first main-tree diff_assert overlapped the main battery and its grep reference mis-encoded é; it was re-run with the tree quiet.
  * The suite was re-frozen once, after the battery, to fix a comment miscount ('19 H rows' should be 18 H rows and Q7). The diff is comment lines only, and the subset re-run on 865d94a3 gave identical verdicts.
  * The xschem and T1 arms in the shapes use the main tree's src/xschem (built 09-17), as in every earlier round.
  * Deliberate disguise stays out of scope (D18): NBSP or ZWSP prefixes, HTML with attributes, tables, links, task lists, and a second stamp hidden the same way. It is now stated in spec §6 and in the checker header.
  * lstat followed by open is not atomic, so a file swapped for a FIFO between the two calls would block. This needs a concurrent writer, not a corpus shape (INFERRED). Tcl 8.6's open has no O_NOFOLLOW.
  * In the plain check rows that build fixtures inline (Q5 as before, and the in-process half of Q11), an error thrown outside their catch would still kill the suite. This is theoretical (READ): none of those calls failed in any shape measured.
  * Q11 needs tclsh and mkfifo on PATH, as S20 needs tclsh. If either is missing, Q11 goes red by name and never hangs (READ).
  * Not measured: a checkout under a directory whose name is not valid UTF-8, run under C.UTF-8. Tcl's own script path would not round-trip there (INFERRED, pre-existing).
  * The suite's istamp_listing, the evidence tool Q5 uses, still silently skips a name that lstat cannot see.
  * Carried over from earlier rounds: summarize_all drops skip: lines (D12); GIT_ATTR_NOSYSTEM is unmeasured; HAVE_GIT depends on timeout; quote_holds may still lazily fetch in an online blob:none clone (latent); uutils timeout costs 100 ms per exec; redundant layer I2.

## S1-fix7 refuter (verbatim)

## refuted: True
## reasoning: S1-fix7 is refuted on one measured regression. I found no class-A failure.

**What reproduced (MEASURED; frozen copies checked against the main tree: checker 6d0592ad, suite c4741eaa, baseline d19e7a82, spec 1d4f8efb; HOME=scratch, DISPLAY unset, every command under timeout):**
- **Main tree.** tclsh, xschem and T1 spelling each give ALL PASS (93 checks), 0 `skip:` lines, rc 0, case_failed 0. LANG=C tclsh and T1 give the same. CLI: `ok (0 problems)`, 87 parser cases. report: 4689 / 931 / 1200.
- **Red-first.** The final suite on aa5cece0's checker and baseline gives `8 FAILED`: exactly B1 G3 Q13 Q14 Q15 Q16 Q17 H22.
- **Stranger shapes, 4 arms each, corpses 0->0.**
  - ALL PASS 93: full clone, worktree, `we ird[x] %41`, café (also under LANG=C), blob:none.
  - `--filter=tree:0` (new here): ALL PASS 93.
  - d1: 90 + 3 named skips (G4 D9h H9).
  - export and unborn: 86 + 7 skipped.
  - reinit: RED by design, 3 FAILED (D9 D9h H9), CLI 10 problems.
- **Genuine defects.** Red sets are identical on final and aa5cece0 bytes:
  - all four at once: B1 D9 D9h H9;
  - bogus tree= and blob tree=: D9 D9h H9 each;
  - unstamped file: B1 D9;
  - rotted quote: D9.
- **Every earlier class-A recipe is inert on the final bytes.** Across textplants, rf6, rf6b and rf7, README was unchanged, 0 markers fired and no `&1` appeared.
  - Injection recipes: `pat=` values `>`, `2>`, `|`, `>file`, `2>&1` and `<` are literal. `2>/dev/null` and `&` are RED. `quote=--output=`, `..`, absolute and `-` paths are refused.
  - Links and FIFOs: a FIFO, a link to a FIFO, and a link out, as an issue file or as the baseline, are each named in 0.2-0.7 s.
  - Other earlier recipes: md_strip lines of 50k characters take 0.6 s, and the non-UTF-8 dir token is RED in both locales.
  - A1: `doc/claude/issues`, `doc/claude` or `doc` linked out gives CORPUS OUTSIDE; report says `not counted`; the suite reds B1 B4 D9 D9h H9 as NOT-READ; 0 output lines mention 9994-9998. `src` linked out, or `src` -> `..`, is `not counted`. `src` holding links to `/`, `..` or itself: report counts are unchanged. A FIFO in `src`, and a link to a FIFO in `tests`: report returns in 0.5 s.
  - A2 (rf7, blob:none): 0 fetch trace lines and packs 8->8 in every recipe. The absent-blob quote is NOT VERIFIED by name; a missing path and a rotted quote are RED.
  - A2, suite run in blob:none (tclsh, xschem, T1, CLI): packs 8->8, object files 8->8, no `.git` file changed. Every fetch line in the trace belongs to the suite's own scratch fixtures.
  - A2, treeless clone: suite packs 12->12. A treeless quote takes the unexercised `tree ... not in this checkout either` branch, with 0 fetch lines.
  - A3: 100 blocks take 61.4 s, 73 of them named as over the budget.
- **Hermetic writes hold.** GIT_DIR/GIT_INDEX_FILE pointed at a victim repo, or at the tree under test: byte-identical. Pre-commit hook with `commit -a` and `commit -- README`: rc 0, 0 fixture files in HEAD. Hostile config: 0 markers. Warn config + GIT_TRACE: ALL PASS.

**The regression (MEASURED).** The new H22 fixture `g clone -q --filter=blob:none "$5" partial` runs inside the fixture script, which uses `set -e`. `GIT_NO_LAZY_FETCH` is not in FIXTURE_ENV_UNSET; the suite says so itself at H21: "GIT_NO_LAZY_FETCH is not one of the fixture environment's names". A caller that exports `GIT_NO_LAZY_FETCH=1` therefore makes the clone's checkout fail. `HF_ERR` then takes down every H fixture.
- Main tree, final bytes: tclsh and T1 spelling each give `RESULT: 20 FAILED (73 passed)`, rc 1, case_failed 1. The reds are H1-H5 H8 H10-H22 and Q7, each `got: FIXTURES NOT BUILT: warning: lazy fetching disabled; some objects may not be available`.
- Full clone, final bytes: the same 20 FAILED on tclsh and on xschem.
- aa5cece0's bytes in the same env: tclsh, xschem and T1 each give `ALL PASS (87 checks)`, rc 0.
- The CLI gate is unaffected (`ok`).

This contradicts the suite's own contract (H21: "the caller's ... GIT_NO_LAZY_FETCH get no vote") and T1's zero baseline. The failure is fail-closed (a false red, not a safety hole). A measured one-word fix exists: adding `GIT_NO_LAZY_FETCH` to FIXTURE_ENV_UNSET gives ALL PASS 93 both with and without the variable exported.
## class_A:
## regressions:
  * MEASURED: new in S1-fix7, not caused by a hostile corpus. When the caller's environment exports GIT_NO_LAZY_FETCH=1, the final suite is RED everywhere, while aa5cece0 stays green.
- Main tree, tclsh and T1 spelling (`cd tests && ../src/xschem --nogui --pipe -q --script headless/test_issue_stamp.tcl`): `RESULT: 20 FAILED (73 passed)`, rc 1, case_failed 1. The reds are H1 H2 H3 H4 H5 H8 H10 H11 H12 H13 H14 H15 H16 H17 H18 H19 H20 H21 H22 Q7, each `got: FIXTURES NOT BUILT: warning: lazy fetching disabled; some objects may not be available`.
- A plain full clone gives the same 20 FAILED on tclsh and on xschem.
- aa5cece0's bytes in the same env and shape: tclsh, xschem and T1 each give `ALL PASS (87 checks)`, rc 0.
- Cause (READ): the new fixture step `g clone -q --filter=blob:none "$5" partial` (test_issue_stamp.tcl, istamp_hist_fixtures) needs lazy fetch to check out HEAD's blobs. The fixture script is `set -e`, and `GIT_NO_LAZY_FETCH` is not in FIXTURE_ENV_UNSET: the comment in H21 says 'GIT_NO_LAZY_FETCH is not one of the fixture environment's names'. So one failed clone becomes HF_ERR, and every H row plus Q7 fails.
- This contradicts H21's own contract ('the caller's GIT_SHALLOW_FILE and GIT_NO_LAZY_FETCH get no vote') and T1's ZERO baseline. The variable is a documented git safety switch, the exact one this checker now sets on every call.
- Remedy, MEASURED in the scratch copy shapes/nlfx: adding GIT_NO_LAZY_FETCH to FIXTURE_ENV_UNSET gives ALL PASS (93 checks) both with GIT_NO_LAZY_FETCH=1 exported and without it. H21 sets and restores the variable itself inside with_fixture_env, so it is unaffected.
- Logs: /var/tmp/xschem_fixes/s1fix7_verify/logs/runs/nlf_{main,main_t1,fin,fin_xs,pre,pre_t1,pre_xs,x_env,x_plain}.*.log (nlfx_env/nlfx_plain for the remedy).
## class_B_followups:
  * Class C, MEASURED: the 'total budget for all the assert= scans' is really a wall clock for the whole gate, started when the gate starts. So slow non-scan work before an assert exhausts it, and the assert is then misreported.
- Recipe: 240 VALID quote= blocks (distinct ancestor revisions, path=README, the README's first line) appended to stamped 0056. Every one holds.
- Final bytes: rc 1 in 69.9 s, `1219:72: assertion could not be evaluated -- the search ran past the gate's total budget of 60 s for all the assert= scans of one run`. 1219's real scan takes about 70 ms, so the wording is false.
- aa5cece0: `ok (0 problems)` in 70.1 s. With 200 blocks both give ok in 57 s.
- A slow box or filesystem, or slow git, shrinks the same margin; the real corpus reaches 1219 in about 0.4 s here.
- Suggestion: charge only scan time, or name the cause truthfully. Logs: logs/bd_fin4.log, bd_pre4.log.
  * Class C, MEASURED (scripts/nearmiss.sh): honest content in a stamped file is falsely red on the final bytes and `ok` on aa5cece0. This follows D19's B1/B2 wording, and the real corpus is unaffected (0 such lines).
- An mkdocs-style fence ```` ```python title="example.py" ```` is named, because `title=` is an unknown key.
- ```` ```sh cc=gcc make ```` is named.
- A stamp body quoted inside a fenced documentation example (`see `v1 claim=open ...``) is named, in both a stamped file and grandfathered 0057.
- Consider marking a fence only by a KNOWN key, and skipping body detection inside fences.
  * Efficiency, not class A (MEASURED): nothing bounds the git work that quote= and tree= blocks cause across a whole run.
- 50 quote blocks with distinct bogus revisions: 16.0 s wall and 0.76 s CPU on the final bytes, and 16.0 s on aa5cece0 (identical, pre-existing).
- 30 ancestor quotes: 10.7 s on both.
- New in a blob:none partial clone: each quote of absent content runs an uncached `ls-tree -r` of the whole revision plus 3 execs. 50 blocks took 26.1 s wall and 6.0 s CPU, with packs unchanged.
- Cost is linear, git calls are timeout-bounded, and the CPU is about 1/17 of A3's per block.
- Suggestion: cache ls-tree per revision, and count quote work in the run's budget.
  * Minor, MEASURED: problem output is uncapped. One marked fence whose info string holds 200k stray words (a 404 KB issue file) produces a single 5.8 MB problem line in 0.7 s. It is linear, but the problem text could be capped at the first N words.
  * Observation, MEASURED: in a --filter=tree:0 clone, a quote of a path the revision never had is NOT VERIFIED by name ('the tree of <rev> is not in this checkout either') rather than RED. That is acceptable under D18 C, which requires RED only in a full clone. No fetch occurred and packs stayed 12->12. This exercises the branch the receipt listed as covered by no row, so a row could hold it.
## out_of_scope:
  * Deliberate disguise (NBSP or ZWSP before the stamp, HTML with attributes, tables, links, task lists) was not re-tested; D18 puts it out of scope, and nothing in S1-fix7 changes it.
  * Report reading whole files into memory (MEASURED with a 300 MB file in tests/): the final Tcl census took 13.9 s and 0.93 GB RSS, against aa5cece0's grep-based report at 35.4 s and 2.57 GB. That is better, not a regression. Counts differ by 10 lines (9831580 vs 9831570); the census is advisory.
## real_home_check: `md5sum -c --quiet /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/xschem_manifest_fixes.md5` gave rc 0 before any work and rc 0 after all of it.
- **Real home and other trees.** `find ~/.xschem ~/.claude/xschem_dev_display ~/.claude/gui_test_gate -newer /var/tmp/xschem_fixes/s1fix7_verify/.marker_start` printed nothing. The same find over ~/dev/xschem-op-wcard (excluding .git) printed nothing. :99, devdisplay and gui_test_gate were never touched.
- **How runs were made.** Every tclsh, xschem, T1, CLI, report and git run used HOME=/var/tmp/xschem_fixes/s1fix7_verify/homes/<tag>, with DISPLAY and GIT_EDITOR unset, under `timeout`.
- **Main tree.**
  - It had only clean suite, CLI and report runs, plus the GIT_NO_LAZY_FETCH=1 env runs, with no plant of any kind.
  - HEAD is still aa5cece0, and the four files are unchanged (6d0592ad c4741eaa d19e7a82 1d4f8efb).
  - `git status` matches the start.
  - `tests/headless/.scratch` is empty, and there is no `&1` or `tests/&1`.
  - Nothing was committed, stashed, reset or checked out.
- **Where writes went.** Every plant, link, FIFO, partial or treeless clone and git write was under /var/tmp/xschem_fixes/s1fix7_verify/shapes (clones of my own file:// mirror of the main tree), or under its `outside*` and `markers` directories.
  - The hookclone's two commits stayed in that clone.
  - Partial-clone remotes were only my scratch mirror and the suite's own scratch psrc.
  - /dev/zero was never read.
- **Leftovers.** 0 FIFOs under my scratch, 0 /tmp/istamp_* entries, and a /proc/*/environ scan found 0 live processes with my scratch HOME.

## IMPL deviations + open_problems (S1-fix7 crew):
  * quote_gap (the partial-clone quote treated as NOT VERIFIED by name) was not in D19's list. A2 forced it: with lazy fetch off, a genuine old quote in a blob:none clone would have gone falsely red. It is fail-closed three ways: a verified revision only, a repository whose own config names a promisor, and the path listed in the revision's trees. H22 holds it with sabotages N2, N3b and N4. It also closes the carried 'offline blob:none quote' limit. The CLI tail wording and D9h's exclusion of such gaps follow from it.
  * report confines and Tcl-scans src and tests as well as the issues dir. MEASURED: with src linked out, report counted 7000 lines outside the checkout. So there is no grep exec left at all.
  * B1 also names an unknown key and a repeated key, not only a word that is not key=value. A fence with no key=value word at all is left alone; 0 real fences are affected.
  * The baseline refuses itself as a whole, by line number, on a bare number or any stray line. An old number-format baseline beside the new checker therefore gives BASELINE UNUSABLE (MEASURED during an rf7 restore slip).
  * gate is now a wrapper around gate_body, so the run's deadline is cleared on every way out.
  * One self-test known negative was re-expected: '# see **STAMP:** <full body> in the spec' is exactly what B2 now names. The mention negative now uses `v1 ...`, as Q4 always did.
  * B1's got value now lists file names, not numbers. D9h leaves partial-clone content gaps out of its empty-skip column; they are still printed by name.
  * Q5 and H17 now build whitespace-free relative targets. The first final battery measured both red in the 'we ird[x] %41' shape: the scratch path contains a space, and B1 correctly named the two-word info string. The fix was re-proved with sabotages X1 and I3. The suite was re-frozen and the whole battery re-run.
  * Harness slips, all re-run and none in the owned files: emoji HOME tags broke the xschem binary's startup, re-run with ASCII tags; rf7's restore re-checked-out the old baseline; textplants' markers directory was missing; score.sh was given relative paths; the non-UTF-8-path clone had to be built via mv because uutils refused its own argv.
  * As in every earlier round, the xschem and T1 arms use the main tree's src/xschem; the shapes were not built.
  * Redundant layer N3: quote_gap's promisor-value check is held by no row alone, because git config already exits 1 when no promisor key exists. The pair is held by N3b.
  * Not exercised by any row (READ, fail-closed or advisory): a partial clone that lacks the revision's tree (tree:0), where the quote is NOT VERIFIED by name; and cite_dir silently leaving out a directory it cannot list (report is advisory).
  * report counts a file as binary only on a NUL byte. grep in a UTF-8 locale also treats encoding errors as binary. The counts measured equal on this tree anyway.
  * A git older than 2.44 ignores GIT_NO_LAZY_FETCH (INFERRED; this box runs 2.53).
  * With an emoji in HOME, the xschem binary fails 'Tcl_AppInit(): failure creating $HOME/.xschem'. That is outside these files; cause UNKNOWN, recorded only.
  * Carried over: lstat-then-open is not atomic; the non-UTF-8 checkout path (now in spec §6); summarize_all drops skip: lines (D12); GIT_ATTR_NOSYSTEM is unmeasured; HAVE_GIT depends on timeout; uutils costs ~100 ms per exec; redundant layer I2; the stale '34 checks' count in spec §5, left as prose.

## S1-fix8 refuter (verbatim)

## refuted: True
## reasoning: S1-fix8 is refuted on three measured regressions. I found no class-A failure. I re-ran every key measurement the claim makes, and each one reproduces.

Setup: my own `--mirror` of the main tree, and clones `final` (d42fc517 plus the four final files), `base` (d42fc517, whose four md5s match the base bytes: 6d0592ad 930eb435 d19e7a82 1d4f8efb) and `aa5` (aa5cece0). Everything is under /var/tmp/xschem_fixes/s1fix8_verify/. Every run used HOME=scratch, DISPLAY unset and a timeout.

**What reproduced (MEASURED):**
- **Suite on final.**
  - tclsh, xschem and T1 spelling each give ALL PASS (97 checks), rc 0, case_failed 0, 0 skip lines, corpses 0->0.
  - GIT_NO_LAZY_FETCH=1 (tclsh, and T1 in the worktree) and LANG=C LC_ALL=C each give ALL PASS 97.
  - CLI: `self-test PASSED (103 parser cases)`, `ok (0 problems)`. base has 87 cases, aa5 has 62.
  - report: 1047/10/1037, citations 4689/930/1180.
- **Row red-first.** The final suite on the base checker gives `RESULT: 5 FAILED (92 passed)`, exactly Q14 Q18 Q19 Q20 Q21, with the claimed got-values.
- **Stranger shapes.** Seven suites ran concurrently, which also put Q20 under load:
  - worktree, `we ird[x] %41`, blob:none: ALL PASS 97.
  - d1: 94 + 3 skipped (G4 D9h H9).
  - export and unborn: 90 + 7 skipped.
  - CLI ok in every shape.
- **Real corpus parse diff.** My own dp.tcl, base vs final: 1050 files and 5032 fence lines, 0 differences in find_blocks, stray_stamps, find_stamp, stray_attrs and fence_info.
- **Item 1.** All 21 honest fence info strings are ok on final and on aa5; 12 of them are rc 1 on base (logs/battery_fences.out). The honest strings: mkdocs title, three pandoc attribute forms, cc=gcc, CC=gcc, prefix=, hl_lines/linenums, fix= alone and with a comment, `text quote`, `python assert`, `assert x == 1`, titles holding quote/assert, env assignments, path= alone, pat= alone. All 10 S1-fix7 near-misses stay RED. ASSERT=, `assert =` and QUOTE= each give 1 problem (base gives 2).
- **Item 2.** A body in a ```, ~~~, 2-space, 3-space list-item or bare fence gives ok on final (rc 1 on base, ok on aa5). The colon-less typos (`**STAMP**`, `STAMP`, `**Stamp**`, `**STAMP -**`, `**STAMP;**`, `**STAMP.**`, `__STAMP:__`) at line 3 of 0057 stay RED. The 1349 collision and a misnamed file stay RED.
- **Item 3.**
  - 240 valid quotes in 0056: base rc 1 in 75.9 s with the false `1219:72 ... 60 s for all the assert= scans`; final ok in 76.0 s.
  - A3: rc 1 in 61.7 s, 100 problems, 84 named by the scanning budget and 0 by the gate's. The claim says 74; the count depends on box speed, and the bound holds.
- **Item 4.** Longest line: 444 for 1M stray words (base 34 889 136), 321 for a 1 MB pat=, 730 for path=, 535 for a quote path, 193 for tree=. Six other stamp fields at 1 MB each stay under 210.
- **Genuine defects (full clones).** All four at once gives B1 D9 D9h H9. Singly: bogus gives D9 D9h H9, unstamped B1 D9, blob D9 D9h H9, quote D9. CLI problems match.
- **Sabotages spot-checked.** F1 reddens Q18 D9b, G2 Q19 D9b, H1 Q20, K1 Q21 D9b.

**Class A, none found (MEASURED).**
- The 22 textplants: README unchanged, 0 markers, no `&1`.
- An issue file that is a FIFO or a link out, and the issues dir linked out: each is named in 0.6 s; report says `not counted`.
- blob:none with an absent-blob quote under GIT_TRACE: 0 fetch lines, objects and packs 8->8, the blob still absent, NOT VERIFIED by name.
- GIT_DIR/GIT_INDEX_FILE/GIT_WORK_TREE pointed at a victim repo: victim md5 993ad047 before and after, ALL PASS 97.
- New code paths stay linear:
  - 100k and 400k fences in a grandfathered file with a body: 2.7 s and 6.5 s;
  - 50k marked fences: 3.6 s;
  - 200k prose bodies: 1.8 s;
  - 1 MB of `>` plus 300k `- ` markers: 0.6 s.

**The regressions.** R1 is a false red against aa5cece0 on honest content, and it is identical on base. R2 and R3 are silent passes where base named the defect. Each has a remedy, measured in the scratch copy `remedy` (details under regressions).
## class_A:
## regressions:
  * R1, regression against aa5cece0 on honest content (base is red identically). MEASURED; logs/battery_bodies.out and logs/*_b_{bq,nested}_*.log.
- Recipe: a stamp-body example with no STAMP word (``see `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=0` ``) inside a well-formed, closed fenced code block.
- Blockquote form (`> ```text` / `> see ...` / `> ````): final rc 1, `a line carrying a stamp's body`, in stamped 1219 and in grandfathered 0057. aa5cece0 `ok (0 problems)` in both. base rc 1.
- Nested-list form (fence indented 5 spaces under `1. First` / `   - Write the stamp:`): the same result.
- markdown-it 3.0.0 (commonmark preset) renders both bodies as <pre><code>. So they are documentation examples, exactly like the ```, ~~~, 2-space and 3-space list-item fences that final now exempts; those all measured ok.
- The task said stamp examples in fences of every kind must not go red. The crew records this as open item 2 ('carried').
- Spec section 6 overstates the limit ('a list item'): a list-item fence at 3 spaces or fewer IS exempt (b_list1: ok on final).
- Remedy measured in scratch copy `remedy`: compute stray_stamps' `inside` over container-stripped text, `fence_scan [regsub -all -line {^(?:[ \t]*>)*[ \t]*} $text ""]`.
  - Both forms are then ok.
  - Indented-code, <pre>, unclosed-fence and inline-prose bodies stay RED.
  - Real corpus: 0 differences (1050 files).
  - Q19 stays green.
  * R2, regression against base (fail-open), MEASURED; logs/battery_typo.out. A fence whose marking key is misspelled is no longer named.
- Recipes, appended to stamped 1219: `asert=`, `assertion=` or `asserts=` on a FALSE assertion (`pat=SABOTAGE path=src state=holds`, 8 real hits); `qoute=` or `quotes=` on a ROTTED quote (`61af3692 path=README`, body not in the file).
- base: rc 1, named (`1219:86: a marked fence the parser cannot read in full -- `asert=absent` has a key the grammar does not know`).
- final: rc 0, `ok (0 problems)`, a silent pass. aa5cece0 also passes it.
- Controls with the correct keys are RED on all three.
- D18-B: near-miss spellings an honest author produces by accident are named, never silent passes. The loss follows from marking only by quote=/assert=, which the receipt says the task specified.
- Remedy measured in `remedy`: `variable fence_marks {quote assert path pat state}`.
  - All 5 typos RED.
  - All 20 honest fence recipes still ok; `sh quote="$1"` is red on all three versions.
  - Real-corpus CLI ok, real-corpus parse diff 0.
  - Cost: the self-test case `{sh ASSERT=absent pat=x ...}` must expect `{3 1}`, and Q18 then counts ASSERT= twice (got `0 0 0 0 0 1 1 2 4`), which is base's double-naming. Keeping it named once needs fence_info to leave case-variant quote/assert words to stray_attrs.
  * R3, regression against base (fail-open), MEASURED; logs/*_adv_slack_*.log and *_adv_inline_*.log.
- The trigger: fence_scan takes a line beginning with ``` as a fence opener even when its info string contains a backtick. CommonMark forbids that, so the line is an inline code span, which is common Slack-style writing. Everything up to the next bare ``` line then counts as 'inside' a closed fence, and the new body skip hides a stamp body in prose there.
- Recipe: '```make install``` fails here, see below.' then 'The old stamp was **STAMP** `v1 claim=fixed tree=deadbee0 ...`' then a normal ```sh fence.
- markdown-it renders the body as a prose <p>.
- base: rc 1 (`1219:88` / `0057:94: a line carrying a stamp's body ... preceded by `The old stamp was **STAMP**``), the mid-sentence body D19 requires to be named.
- final: `ok (0 problems)` in both stamped 1219 and grandfathered 0057, so the bogus tree=deadbee0 goes unchecked. aa5cece0 is ok.
- A variant (``` `x` ``` at line start, then a colon-less `**STAMP** `v1 ...``) gives the same split.
- Severity is lowest of the three: the header-window typo cannot be reached, because line 1 is the title.
- Remedy measured in `remedy`: add `&& !([string index $fence 0] eq "`" && [string first "`" $info] >= 0)` to fence_scan's opener test.
  - Both recipes are then RED; honest fence examples stay ok.
  - The real corpus has 0 such lines, and the parse diff against final is 0 over 1050 files and 5032 fence lines.
  - Suite with all three remedies: 96/97, only Q18 red, from R2's double-naming.
## class_B_followups:
  * A stamp-body example is still named, although CommonMark (markdown-it) renders it as code, in three cases MEASURED red on final and on base and ok on aa5: a 4-space-indented code block, an HTML <pre> block, and a fence left unclosed at end of file. Each is defensible fail-closed (an indented or unclosed near-miss is ambiguous, and the crew's deviation 3 is deliberate), so I list them as follow-ups, not blockers.
  * Spec section 6 says 'A fence inside a blockquote or a list item is not seen as a fence'. A list-item fence indented 3 spaces or fewer IS seen and exempt (MEASURED b_list1 ok). Only fences indented 4 or more spaces (nested lists) and blockquoted fences are not seen.
  * A pre-existing false red, the same at aa5, base and final (READ from the code, INFERRED, not planted): a Slack-style ```inline``` line before a real ```sh assert=... fence would swallow that fence, and stray_attrs then names it 'inside another fenced block'. R3's CommonMark opener rule would fix this too.
  * A3's count of blocks named by the scanning budget is box-dependent: 84 here against the claimed 74 (MEASURED). The bound holds at 61.7 s. The receipt's '74' should be read as one run's value.
  * Q20 depends on real sleeps: part B needs about 100 ms of margin, part C needs setup under 0.5 s. It was green in about 20 of my runs, including 7 concurrent suites. I deliberately did not saturate the CPU, because the driver's T1 gate was reading the main tree.
  * t_gate_total (600 s) is a new fail-closed failure mode that depends on the box. The real corpus takes 0.6 s. The crew disclosed it (spec section 6).
## out_of_scope:
  * A stamp body in inline code in prose (`The format is `v1 claim=...` as written.`) is RED on final and base and ok on aa5 (MEASURED). D19 explicitly requires a mid-sentence body to be named, so this is by design.
  * A valid quote=/assert= block with an extra word or an unknown key=value (for example a title=) in its info string is RED on final and base; aa5 ignored such words. D19-B explicitly makes it named.
  * A full `**STAMP:** `v1 ...`` example inside any fence is RED at aa5cece0, base and final alike (crew's measurement; not re-planted). It is pre-existing and recorded in spec section 6.
  * Not re-run by me: the reinit red-by-design shape, rf6b's non-UTF-8 recipes, reportplants, and the pre-commit-hook hermetic test. The code paths they exercise are unchanged by S1-fix8 (READ from the diff).
## real_home_check: `md5sum -c --quiet /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/xschem_manifest_fixes.md5` gave rc 0 before any work and rc 0 at the end.

- **Real home.** `find ~/.xschem ~/.claude/xschem_dev_display ~/.claude/gui_test_gate -newer /var/tmp/xschem_fixes/s1fix8_verify/.marker_start` printed nothing. The same find over ~/dev/xschem-op-wcard (with .git pruned) printed nothing. :99, devdisplay and gui_test_gate were never touched.
- **Main tree** /home/analog/dev/xschem-claude:
  - not edited;
  - HEAD is still d42fc517;
  - the four files are still 6d0592ad 930eb435 d19e7a82 1d4f8efb;
  - `git status` is unchanged from the start (7 entries);
  - tests/headless/.scratch has 0 istamp_/drv_ entries, and there is no `&1`.
  - Only read-only git ran against it: my `clone --mirror`. Its src/xschem binary was executed only from scratch clones.
- **Crew's final bytes** in /var/tmp/xschem_fixes/s1fix8/final are unchanged: b373429b accdf887 d19e7a82 97482872.
- **Where writes went.** Every plant, link, FIFO, clone, worktree, remedy edit and sabotage stayed under /var/tmp/xschem_fixes/s1fix8_verify/. Every plant was restored (git status of the issues dir: 0).
- **Leftovers.** 0 FIFOs, 0 /tmp/istamp_* entries. A /proc/*/environ scan found 0 live processes with an s1fix8_verify HOME; I did not use `pgrep -f`.

## IMPL deviations + open_problems (S1-fix8 crew):
  * Item 3 has two budgets. The assert= total is scanning time only (60 s). The old wall clock is kept as a separately named whole-gate budget, t_gate_total 600 s, so git work (quotes, tree=) is bounded too. When it is spent, each tree=, quote= and assert= is named by a sentence saying the gate's time ran out. The cost is that a box slow enough to take 600 s on the real corpus goes red, saying why (spec section 6).
  * A fix=-only fence is no longer a block: marking is by quote= or assert= only, as the task specified. fix= was never evaluated (READ gate_body), so no verdict changes.
  * The fenced-body skip applies only to fences that close. Bodies in never-closed fences and on a fence's opening line stay RED (fail-closed); Q19 and sabotages G2 and G3 hold this.
  * Item 4 goes beyond 'first N stray words'. Every corpus word a problem quotes is clipped, and there is a 2000-char backstop on problems and NOT VERIFIED lines. The recipes found 1-3 MB lines from pat=, path=, a quote path and a stamp token.
  * Q14's cleared-check is false (not an error) when the new variables are absent, so that on the base checker Q14 and Q20 report every part instead of ROW DIED.
  * The suite was re-frozen once. In the first sabotage pass, F2 reddened only D9b, so Q18's fix= fixture gained a trailing comment. Everything that runs the suite was re-run on 97482872; the checker and spec did not change.
  * Harness slip, not in the owned files: my path rewrite of the refuter's rf6.sh pointed its restore at a nonexistent directory, deleting plant's baseline. The first class-A pass was void and was fully re-run after the fix.
  * The xschem and T1 arms use the main tree's src/xschem, as in every earlier round; the shapes were not built.
  * The main tree's HEAD moved aa5cece0 -> d42fc517 (the driver's commit of exactly the base bytes) during the run. My clones are aa5cece0 plus the installed files. They differ from d42fc517 only in receipts and the ledger, which nothing under test reads.
  * A stamp written inside a fence is still read as one. find_stamp reads a column-0 **STAMP:** line inside a fence, and the stamp-shaped check names `STAMP:`+body there. Both are fail-closed reds, measured identical at aa5cece0, and the real corpus has neither. Item 2 was scoped to body detection. Recorded in spec section 6.
  * A fence inside a blockquote or list item is not seen as a fence (carried), so a stamp body quoted there is still named.
  * The 600 s gate wall clock depends on the box. Quote git work is now bounded by it but not made faster: ls-tree is still uncached per revision (the refuter's efficiency note).
  * Q20 uses real sleeps. Part C needs the gate's setup to take under 0.5 s; it takes milliseconds, and the row was green in 56 logs under load, but it is a margin.
  * Sabotage K2 (the 2000-char backstop disabled) is held only by D9b's self-test, because every known site now clips before the backstop.
  * Carried from S1-fix7: lstat-then-open is not atomic; the non-UTF-8 checkout path; summarize_all drops skip lines (D12); GIT_ATTR_NOSYSTEM is unmeasured; HAVE_GIT depends on timeout; uutils costs ~100 ms per exec; redundant layers I2 and N3; the tree:0 branch is held by no row; git before 2.44 ignores GIT_NO_LAZY_FETCH (INFERRED); the stale '34 checks' in spec section 5.

## S1-fix9 refuter (verbatim)

## refuted: True
## reasoning: S1-fix9 is refuted. Its R1 remedy introduces two regression families; both are MEASURED on the final bytes (75c8aa17 04bc9ef6 d19e7a82 261c1ac7). There is no class-A finding.

**The cause (READ).** The R1 remedy changed one line in `stray_stamps`: `inside` now comes from `fence_scan [regsub -all -line {^(?:[ \t]*>)*[ \t]*} $text ""]`. The strip is applied to the whole text, including the bodies of real column-0 fences. Two things go wrong:
- A `> ```` line, or a `    ```` line, inside a real ```md or ```python fence becomes a closer. The real closer then opens a phantom fence. That phantom runs to the next bare ``` of a later fence and flips the body check's view of everything in between.
- A lone ``` line in an indented code block, or in a blockquote that leaves a fence unclosed, pairs with a later fence in the same way.

**Checking that the content is honest.** None of the shapes is a disguise; all are valid CommonMark. markdown-it 3.0.0 (commonmark mode) renders every typo line as paragraph text and every example body as fence content (MEASURED).

**Reproducing the crew's claims (all MEASURED; setup in `real_home_check`).**
- The final suite gives ALL PASS (100 checks) with 0 skip lines and corpses 0→0 in every full shape:
  - `fin` on tclsh, xschem and T1;
  - the renamed clone, the worktree, the weird-path clone, the blob:none clone and `cur`, on tclsh and T1.
- The CLI says ok (0 problems) with self-test PASSED (120 parser cases).
- Stranger shapes match the claim: d1 97 + 3 skipped (G4 D9h H9), export and unborn 93 + 7, reinit 3 FAILED (D9 D9h H9).
- Red-first matches: the final suite gives 3 FAILED (Q22 Q23 Q24) on S1-fix8's checker, and 8 FAILED on d42fc517's.
- The parser diff against S1-fix8 and against d42fc517 is 0 (1050 files, 5032 fence lines).
- The R1, R2 and R3 recipes, the once-naming recipes and the 20 honest f_* fences give exactly the crew's table.
- The class-A scripts (textplants, rf6, rf6b, rf7 A1/A2, reportplants, hermetic, defects) reproduce: README unchanged, 0 markers, 0 `&1`, 0 files mentioning 9994–9998, 0 fetch trace lines, packs 8→8, the victim and self repos byte-identical, and the same defect red sets.
- A3 gives rc 1 in 60.6 s with 100 problems, 86 of them naming the scanning budget. q240 is ok in 75.6 s.
- `stray_stamps` stays linear on adversarial input: 15.7 MB of indented openers in 375 ms.

**The regressions are new in S1-fix9** (S1-fix8's raw scan handles every one correctly), and none is disclosed. Spec §6 names only two different "disguise" shapes, and it calls a ``` line in an indented code block "harmless". The h_indcode1 recipe measures that sentence false.

**A measured remedy.** A scratch prototype, `body_ranges` (rem clone, checker md5 6ac99c4c), fixes both families:
- it blanks every line of each raw fence before the stripped scan;
- it keeps a stripped fence only while every line of it stays inside the opener's container (`>` on every line, or at least the opener's indentation).

With it:
- all h_* are RED and all h2_* are ok;
- every b_* and adv_* recipe gives the same verdict as final;
- the suite gives ALL PASS 100;
- `stray_stamps` has 0 diffs over the 1050 committed files and the 1056 working-directory files;
- it also names both of the crew's stated §6 shapes, so that limit can be deleted rather than stated.

**A process note.** My T1 run on `cur` concurrent with a tclsh run in the same clone showed corpses 0→118. That was the sibling run's live scratch: 0 were left afterwards, and a solo T1 re-run gave corpses 0→0.
## class_A:
## regressions:
  * REGRESSION A: an honest near-miss that d42fc517 names now passes silently (the D19-B 'stamp with its colon missing' class; same family as the S1-fix8 refuter's R3). MEASURED with the CLI gate in stamped 1219 and in grandfathered 0057; each recipe is an ordinary markdown example, then a colon-less stamp in prose, then an ordinary ```sh fence. Verdicts are listed as aa5cece0 / d42fc517 / S1-fix8 / final.
- h_mdbq: a ```md fence showing a blockquoted fence (`> ```text`, `> make install`, `> ````), then `**STAMP** `v1 claim=fixed tree=deadbee0 ...``. Verdicts: ok / 1 problem / 1 problem / **ok (0 problems)**.
- h_mdlist: a ```md fence showing a list item with a 4-indented fence. ok / 1 / 1 / **ok**.
- h_pydoc: a ```python fence whose docstring holds an indented ```sh / ``` example. ok / 1 / 1 / **ok**.
- h_indcode1: an indented code block showing one ```text line. ok / 1 / 1 / **ok**.
- h_bqopen: a blockquote holding only `> ```sh` and `> make install`. ok / 1 / 1 / **ok**.
- j_mdbq_prose and j_mdlist_dash: the same with `The old stamp was **STAMP** `v1 ...`` and `**STAMP -** `v1 ...``. ok / 1 / 1 / **ok**.
- Controls h_ctl and h_ctl2 stay 1 problem on final.
markdown-it (commonmark) renders every typo line as paragraph text. h_mdbq and h_indcode1 were re-measured on a fresh clone at main HEAD 021e9405. Recipes are in /var/tmp/xschem_fixes/s1fix9_verify/rc/, logs in logs/bat_h1_*.out and logs/bat_j_*.out.
  * REGRESSION B: honest content that aa5cece0 accepts now goes red (the same family as the S1-fix8 refuter's R1, which was counted with the same aa5 ok / d42 red pattern; S1-fix8 had this case ok). MEASURED in 1219 and 0057: a stamp-body example inside a real, closed, column-0 fence, placed after an inner container fence. markdown-it renders each body line as fence content. Verdicts are listed as aa5cece0 / d42fc517 / S1-fix8 / final.
- h2_mdex: ```md, `> ```text`, `> make install`, `> ````, a blank line, `see `v1 claim=open ...``, ```. Verdicts: ok / 1 problem / ok / **1 problem**.
- h2_mdlistex: a 4-indented list fence, then `2. Stamp it with `v1 claim=...``. ok / 1 / ok / **1**.
- h2_pyex: a docstring fence example, then `The body is `v1 claim=...``. ok / 1 / ok / **1**.
- Control h2_ctl is ok on final.
This contradicts the claim that 'the fenced stamp examples are still ok'. h2_mdex and h2_pyex were re-measured on the 021e9405 clone. Logs are in logs/bat_h2_*.out.
## class_B_followups:
  * Remedy for both regressions (MEASURED prototype `body_ranges` in /var/tmp/xschem_fixes/s1fix9_verify/rem/tests/headless/issue_stamp.tcl, md5 6ac99c4c). It blanks every raw fence's lines (opener through closer, or opener to EOF when unclosed) before the container-stripped scan. It accepts a stripped fence's range only while every line stays in the opener's container: `>` on every line, or indentation at least the opener's on every non-blank line. Results:
- rtest.tcl: 15 of 15 right (final 6 wrong, S1-fix8 4 wrong).
- The CLI battery: all h_* RED, all h2_* ok, every b_*/adv_* identical to final.
- The suite: ALL PASS (100 checks).
- stray_stamps: 0 diffs over the 1050 committed and 1056 working-directory files.
- It also names spec §6's two stated mis-pairing shapes, so that limit can be removed.
The suite should gain a row for h_mdbq, h_indcode1 and h2_mdex; Q22 covers none of them.
  * Spec §6 says a ``` line inside an indented code block is 'harmless, because the lines between are code either way'. That is false: h_indcode1 hides a colon-less stamp in prose (MEASURED). Fix the sentence together with the remedy.
  * The path=/pat=/state= marking cost goes beyond the crew's example. MEASURED as aa5cece0 / d42fc517 / S1-fix8 / final:
- ```c path=src/move.c (excerpt): ok / red / ok / red.
- ```c path=src/scheduler.c lines 120-140: ok / red / ok / red.
- ```python title="build.py" path=tools/build.py: ok / red / ok / red.
- ```text state=before the fix: ok / red / ok / red.
It meets the letter of the aa5cece0 clause, but it is the stated cost in spec §6 and the S1-fix8 refuter's own remedy verbatim, and the committed d42fc517 is red too. So it is recorded here, not as a blocking regression. Consider narrowing the marking to fences that carry pat= and state= together, or path= plus a quote/assert near-miss.
  * Two backtick-info cases, MEASURED as aa5cece0 / d42fc517 / S1-fix8 / final:
- A TRUE assertion with pat=`ZQXNOPE` (k_btpat_true): ok / ok / ok / RED. Disclosed as deviation 2.
- A backtick-info opener (```sh `make` output) followed by a real TRUE assert= fence (k_flip_true): ok / ok / ok / RED, named 'inside another fenced block'. The pairing flip is not disclosed.
markdown-it agrees with final (neither line is a fence), so this is CommonMark-consistent. The spec should state the flip, and that pat= cannot contain a backtick.
  * `Assert= absent` (a space after the `=`) is still named twice on final: 2 problems (d42fc517 also 2, S1-fix8 1). The 'named once' claim covers `assert =`, `assert =absent` and `assert = absent`, but not the `Key= value` spacing.
  * Fuzz of 40 000 random info strings (fuzz2.tcl), final against d42fc517 (MEASURED): 0 new silent passes, apart from 1249 backtick-info lines (R3, by design) and 3050 fences carrying none of the five marking keys (S1-fix8's intended unmarking). 0 cases where final evaluates a block d42fc517 named.
## out_of_scope:
  * Carried from S1-fix8, not re-litigated:
- K2 is held by D9b alone.
- Q20 depends on real sleeps.
- The 600 s gate wall clock depends on the box.
- A stamp written in a fence is still read as one.
- The '34 checks' in spec §5 is stale.
- The S1-fix7 list: lstat-then-open, the non-UTF-8 checkout path, D12, GIT_ATTR_NOSYSTEM, HAVE_GIT/timeout, uutils cost, I2/N3, tree:0, git < 2.44.
  * Main HEAD moved to 021e9405 (another crew's docs commit adding 1483-1488) after the crew's re-run at 7a46275f. MEASURED on a fresh clone at 021e9405 with the final bytes: CLI ok (0 problems), self-test 120, and ALL PASS (100 checks) with 0 skips on tclsh and on T1 (T1 re-run solo, corpses 0->0).
## real_home_check: MEASURED:
- The manifest check (`md5sum -c --quiet` on xschem_manifest_fixes.md5) gave rc 0 before any work, after all of it, and after the receipt append.
- `find -newer /var/tmp/xschem_fixes/s1fix9_verify/.marker_start` printed nothing over ~/.xschem, ~/.claude/xschem_dev_display and ~/.claude/gui_test_gate, nor over ~/dev/xschem-op-wcard with .git pruned.
- A /proc/*/environ scan (not pgrep -f) found 0 live processes with an s1fix9_verify HOME, and a ps check found 0 processes of mine left.
- 0 FIFOs under /var/tmp/xschem_fixes/s1fix9_verify, 0 /tmp/istamp_* entries, 0 istamp_/drv_ corpses in the main tree's tests/headless/.scratch, and no `&1` file.
- The main tree's four files still read 6d0592ad 930eb435 d19e7a82 1d4f8efb.

How the runs were made:
- Every tclsh, xschem, T1, CLI and git run used HOME set to a directory under /var/tmp/xschem_fixes/s1fix9_verify/homes, with DISPLAY and GIT_EDITOR unset, and each command ran under a timeout.
- The xschem and T1 arms used the main tree's src/xschem.
- :99, the devdisplay, the GUI gate and op-wcard were never touched.

The only main-tree write is an append to /home/analog/dev/xschem-claude/doc/claude/outsider_fixes_batch/receipts/S1.md, a section titled '## S1-fix9 — refutation'. `git diff` on that file shows insertions only.

Everything ran in /var/tmp/xschem_fixes/s1fix9_verify/:
- The clones: fin (final bytes), s8 (S1-fix8 final), d42 (a checkout of d42fc517), aa5 (a checkout of aa5cece0), rem (the remedy prototype), cur (a fresh clone at 021e9405), mix8 and mixd, plus the shapes under shapes/ and rv/shapes/.
- The main tree was only read: a mirror clone, one direct clone, git log/diff, and a cp of the issues directory out of it.

## S1-fix10 refuter (verbatim)

## refuted: True
## reasoning: S1-fix10 is refuted on one regression family, and there is no class-A finding.

**Cause (MEASURED).** Item 3's opener rule changes how fences pair up: a line with a backtick in its info string no longer opens a fence. So a marked fence with a misspelled marking key (asert=, assertion=, asserts=, qoute=, quotes=) is either swallowed by a phantom fence or is itself no fence. stray_attrs only matches `(quote|assert)[ \t]*=`, so nothing names it.

- In stamped 1219, d42fc517 says rc 1: "has a key the grammar does not know".
- The final bytes say rc 0, ok (0 problems).

**What makes this a regression.** It falls under "anything d42fc517 names now passing silently". The crew did not disclose it: the receipt says every item-3 consequence is fail-closed ("named, never passed"). Spec §5 still promises that a misspelled marking key on a block is named, and D21 item 2 says typo'd marking keys are named.

**Proof of cause (MEASURED).** I took the final checker and removed only the item-3 opener condition. Called directly, with the self-test skipped, it names all three probes again, byte-identical to d42fc517.

**Scope (MEASURED).** A fuzz of 20 000 random info strings per context:
- with the fence alone, 0 marked fences go silent, so items 1 and 2 are clean in isolation;
- after a flip opener, 2106 do.

**Honest caveats.**
- markdown-it agrees with final's pairing. Final is CommonMark-correct about structure; what is lost is d42's name for an honest near-miss (D18-B).
- d42 has a mirror-image hole: after a Slack-style ```make install``` fails line, z_r3_asert and z_r3_qoute pass on d42 and are named on final.
- The z_bt_* half (the typo on the backtick-info line itself) was already visible in S1-fix9's refuter's fuzz ("new silent passes … apart from backtick-info lines"). The flip-swallow half (z_flip*, zr_real_*) is new.
- The driver has to decide whether a fail-open consequence of item 3 counts as an "intended difference". I judged it does not: the batch rejected S1-fix9 for a fail-open of the same shape (h_mdbq, a near-miss after a nested example).

**Every key measurement in the claim reproduced (MEASURED):**
- The battery: the crew's 33 differences exactly, and every added 0057 placement identical. The only ok→RED changes are k_btpat_true and k_flip_true, plus z_bt_false from the same family.
- Red-first: 6 FAILED (Q14 Q18 Q20 Q21 Q23 Q24) on d42fc517's checker, and 3 FAILED (Q19 Q22 Q23) on S1-fix9's.
- The real-corpus parser diff is 0 (1056 files, 5032 fence lines), and the report is byte-identical.
- ALL PASS (100 checks) with 0 skips on tclsh, xschem and T1, and the CLI says ok with 122 parser cases.
- The stranger shapes match: d1 97+3, export and export-inside-another-repo and unborn 93+7, reinit RED on D9 D9h H9. The renamed, worktree, weird-path and blobless clones, plus GIT_NO_LAZY_FETCH=1 and LANG=C, each give 100.
- The class-A scripts are inert.
- The sabotages I re-ran (S9e, A10, G8 and K1) each reddened their rows.

The refutation section is appended to receipts/S1.md; it is insertions only, and the only main-tree write.
## class_A:
## regressions:
  * MEASURED, flip swallow. In stamped 1219, a fence opened by ```sh `make` output (item 3 makes it no fence), then its bare ```, then a misspelled-key fence making a false claim (z_flip_asert, z_flip_assertion, z_flip_asserts, z_flip_qoute, z_flip_quotes). d42fc517 gives rc 1, 1 problem: 'has a key the grammar does not know'. Final gives rc 0, ok (0 problems). Recipes are in /var/tmp/xschem_fixes/s1fix10_verify/rc/ and logs in logs/bat/{base,fin}__z_flip_*_1219.log.
  * MEASURED, same with other honest openers. z_flip2_asert (```bash # run `make check` first) and z_flip3_qoute (```console $ `pwd`): d42 rc 1, final rc 0 ok. The realistic file zr_real_asert / zr_real_qoute (```text `make check` output, a FAIL line, a bare ```, prose, then ```sh asert=absent pat=SABOTAGE path=src state=holds with 8 real hits) was re-run on lanes base2 and fin2: d42 rc 1, final rc 0 ok. The control zr_real_ctl, with the canonical key, is red on both.
  * MEASURED, typo on the backtick-info line itself: z_bt_asert (```sh asert=absent pat=`SABOTAGE` path=src state=holds), z_bt_assertion and z_bt_qoute each give d42 rc 1, final rc 0 ok. This was disclosed only indirectly, by S1-fix9's refuter's fuzz ('apart from backtick-info lines').
  * MEASURED, cause. scripts/gate3.tcl calls gate() directly on d42, final, and final with ONLY the item-3 opener condition removed (scripts/fin_S9e.tcl). The last names zr_real_asert, z_flip_qoute and z_bt_asert byte-identically to d42, so item 3's pairing change is the sole cause. scripts/fuzz3.tcl finds 0 such silent passes for a fence standing alone, and 2106 of 20000 after a flip opener.
  * MEASURED, contradicts the crew's own claims. The receipt says item 3's consequences are 'fail closed (named, never passed)'. Spec §5 says 'A misspelled marking key on a block (asert=, qoute=) is named as a key the grammar does not know'. D21 item 2 says typo'd marking keys are named. None of these hold in the rows above.
## class_B_followups:
  * Item-3 fail-open fix candidate, not built: stray_attrs could also match misspelled marking keys (asert, assertion, asserts, qoute, quotes, assert:, 'assert absent'), or name any marked word on a line that the item-3 opener rule leaves unread. Either would restore d42's naming without undoing the CommonMark opener rule.
  * Item-1 consequence, not blocking under D21's wording: a fence whose only key-shaped word is a misspelled marking key goes from named on d42 to ok on final. z_k_asert_alone (```sh asert=absent) and z_k_qoute_fix (```c qoute=... fix=...) were MEASURED. S1-fix9's refuter's fuzz disclosed this as 'fences that carry none of the five marking keys'.
  * Carried: the d42 mirror-image hole. z_r3_asert and z_r3_qoute, a misspelled key after a Slack-style ```make install``` fails line, pass on d42 and are named on final. Whatever is kept, one side has a swallowed-typo hole; a checker that names misspelled marking keys wherever it finds them would close both.
  * Carried from the crew: the path=/pat=/state= marking cost (m_* red on both), cx_k_nomark ok on both, K2 held by D9b alone, Q20 real sleeps, the 600 s budget depending on the box, the stale '34 checks' in spec §5, and the S1-fix7 list.
## out_of_scope:
  * k_btpat_true, k_flip_true and z_bt_false go from ok to RED. These are item-3 consequences the crew disclosed; markdown-it agrees and they fail closed. I did not count them as regressions, but the driver should still confirm, per the receipt's deviation 3.
  * z_k_asert_alone and z_k_qoute_fix are named on d42 and silent on final. That is item 1's 'marked only by a marking key' rule as D21 words it.
  * The D21 limit itself: a stamp body inside a fence in doc/claude/issues is RED.
## real_home_check: The manifest check `md5sum -c --quiet …/xschem_manifest_fixes.md5` gave rc 0 before any work, before the append and after it (MEASURED).

- `find -newer /var/tmp/xschem_fixes/s1fix10_verify/.marker_start` printed nothing over ~/.xschem, ~/.claude/xschem_dev_display, ~/.claude/gui_test_gate, or ~/dev/xschem-op-wcard with .git pruned.
- A /proc/*/environ scan (not pgrep -f) found 0 live processes with an s1fix10_verify HOME, and ps shows 0 of my jobs left.
- There are 0 /tmp/istamp_*, 0 FIFOs under the scratch, 0 istamp_/drv_ entries in the main tree's tests/headless/.scratch, and 0 `&1`.
- The main tree is at HEAD 32b6a9cd with the four files unchanged: 6d0592ad 930eb435 d19e7a82 1d4f8efb.
- Its only write is my append to doc/claude/outsider_fixes_batch/receipts/S1.md. git diff --stat reports insertions only (+380 in total, of which the crew's is 277 lines).
- Every xschem, tclsh and git run used HOME under /var/tmp/xschem_fixes/s1fix10_verify/homes, with DISPLAY and GIT_EDITOR unset and a timeout.
- :99, the devdisplay, the GUI gate and op-wcard were never touched.
- uploadpack.allowFilter was set only on my scratch mirror.
