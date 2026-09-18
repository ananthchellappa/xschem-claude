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
