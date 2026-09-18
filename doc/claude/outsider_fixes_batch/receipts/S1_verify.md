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

