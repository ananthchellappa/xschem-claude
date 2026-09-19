# S2c round 4: refuters (workflow wf_1691f504-ff2)

Verbatim; both refuted=false. Full refuter write-ups: S2c-R4-refute-safety.md, S2c-R4-refute-regression.md.

########## safety: refuted=False
NOT REFUTED on safety. Receipt: /home/analog/dev/xschem-claude/doc/claude/outsider_fixes_batch/receipts/S2c-R4-refute-safety.md

Nothing the harness killed or deleted belonged to anyone else. No documented command wrote under a canary home outside D13.2 and D9. Tags: M = measured, R = read from source, I = inferred.

**Setup (M)**
- Trees, all built rc 0:
  - fix = main HEAD 32b6a9cd + r4b/r4.patch.
  - base = HEAD, which is round 3.
  - base0 = HEAD with r3b/final_item2_only.patch reversed, i.e. HEAD without Item 2.
- fix matches a clean 334dc0d5 + final_item2_only.patch in all 33 files.
- Every run used env -i with HOME = a seeded or EMPTY canary, a find+md5 snapshot before and after, inotify, and a leftover scan.
- Displays of mine: :190 (T1's DISPLAY), :192 (victim), DEVDISPLAY_NUM 193, test numbers 194/193, and an xvfb-run shim forcing -n 191 -a.
- A decoy zoo of other people's things, checked after every run:
  - 16 perl decoys named Xvfb, openbox, env, x11vnc, xschem, the gate panel and ngspice, some carrying other T1 and shell reaper tags;
  - a live-owned throwaway backdated to 2026-09-10 under /tmp;
  - a live-owned devdisplay_test dir.
- It read 16/0 (all alive, no problems) every time.

**Round-3 safety recipes on fix (M)**
- devdisplay stop, with a dead xvfb.pid and wm.pid = my live openbox on :192: fix killed nothing ('not running (state cleaned)'). base and base0 both printed 'stopped :194' and killed it.
- A stale devdisplay_test dir recording :188 and naming my live Xvfb :192 and its openbox, then test_devdisplay.sh: ALL PASS 53, both alive.
- winshot.sh, xarm.sh (one, suites, mode) and test_ase_migrate.py, on EMPTY and seeded canaries: canary identical, 0 events, no panel, nothing left.
- A custom HOME whose .cache is a link, or whose simulations/{clean,short}.spice are links: refused, sh rc 2 and Tcl rc 3.
- A throwaway-shaped HOME planted directly under /tmp: a note and a fresh arm, in both languages.
- The round-1 and round-2 recipes all behave as round 3 recorded, including TMPDIR in HOME (only tmp/ changes).
- A dead throwaway naming my live display: swept, while my display was spared, in both languages.
- A live bwrap --unshare-pid run's throwaway, backdated 1000 s: survived both host sweeps.

**New shapes (M)**
- T1 as a concurrent seeded + EMPTY pair, alongside r4v2's two T1s: both cases=87 blocks=86 counted_failures=0, canaries byte-identical, 0 events, zoo intact.
- kill -9 of one of two concurrent T1 driver copies during its display arm: the reaper removed its own Xvfb :101 and openbox. The other copy's :100 survived and it finished with 0 counted failures.
- run_suites.sh on the private path, killed -9 at 0.3, 1.2 and 2.5 s: nothing of the run was left.
- test_devdisplay.sh with decoys planted on its own numbers (Xvfb :193, openbox DISPLAY=:194, x11vnc :194): all three survived.
- The devdisplay lifecycle (start, status, view, exec, stop): stop killed exactly its own three processes.
- T1-copy auto-start: the display got the pre-switch HOME and 0 XSCHEM_TEST_ variables, and only D13.2's files changed. devdisplay stop then killed both.
- XSCHEM_TEST_HOME=<custom>: the custom dir stayed byte-identical.
- full_audit.sh on an EMPTY canary: 392 pass / 11 fail / 0 crash / 2 skip (405). The canary stayed empty and nothing was left.

**Why nothing blocks (R)**
- Round 4's new kill paths identify their targets exactly:
  - T1's reaper kills only processes carrying its per-attempt tag.
  - reapers_of checks the reaper's marker and its run dir.
  - _wm_is checks DISPLAY and HOME.
  - The orphan sweep checks the display.
  - The new tests' cleanups stay inside their own scratch.
- The remaining findings are identical in base0, or are sub-millisecond race windows or pid-recycle windows I could not measure, so they go in followups.
## blocking:
## followups:
  * F1 (M, identical in base0): D9's exception has a second documented spelling. CLAUDE.md documents `devdisplay.sh exec ./src/xschem --pipe -q --script ...`, and it writes the real ~/.xschem: clipboard 103->201 and geometry 5064->5300, on fix and base0 alike. The done-claim's D9 exception should name devdisplay exec, as round 3's refuter already asked.
  * F2 (M, opt-out; base0 the same): with XSCHEM_TEST_HOME=real, run_suites.sh's private arm writes the real ~/.cache/openbox, because xvfb_arm's openbox keeps the real HOME. T1's private arm deliberately gives openbox the run dir even under =real, so the two arms disagree.
  * F3 (M, identical in base0): `devdisplay.sh view --stop` has no 'no server, no kills' gate. With a dead xvfb.pid and vnc.pid naming my live `x11vnc -display :194` decoy, fix and base0 both killed it and printed 'viewer stopped (:194 still running)'. D20.1 closed this for `stop` but not for its sibling.
  * F4 (R/I, not measured): lock removal is read-then-remove in four places: T1 reaper phase 3, t1_home_kill_xvfb, devdisplay _rm_lock_if_names, and test_devdisplay's D18/D19 lock plant (`[ ! -e ] && printf >`). A server that takes the number inside the millisecond window loses its lock. Consider link/rename-based or re-verified removal.
  * F5 (M, identical in base0): spawn_reaper's _reaper_owner_state cannot tell a live run in another pid namespace from a dead one, unlike test_home's D13.6 rule. Measured: from inside `bwrap --unshare-pid`, reaper_sweep_orphan_runs rm -rf'd a devdisplay_test.* dir whose .reaper_owner names a LIVE host process, on fix and base0 alike. A containerized concurrent test_devdisplay.sh sharing TMPDIR loses its state dir. Its kills stay safe, because ns-local pids fail the argv[0] and display checks.
  * F6 (I): several cleanups kill by a started pid with no identity re-check: test_home_isolation's stop_pid over ::started (it also deletes a /tmp/.X1NN-lock naming that pid), test_devdisplay's exit `kill -9 $SWEEPPIDS $DECOYS` (which includes pids a row already killed), and _sh's kill_all. This is theoretical on this box: about 590 pids/s against pid_max 4194304, so the counter takes about 2 h to wrap.
  * F7 (M, harmless): two T1 runs that auto-start one dev-display state dir at the same time both report 'started', and wm.pid records the second openbox, which exits. `stop` still leaves nothing running, because openbox exits with its server.
  * Scratch for the driver to delete: /var/tmp/xschem_fixes/r4v1 (trees fix/base/base0/chk, canaries, runs, drv, aux, tools) and /var/tmp/xschem_fixes/r4v1s (the marker). All fixtures, decoys and zoo dirs are stopped or removed. The /tmp/xschem-test-home.2425209.* and 2425210.* dirs belong to r4v2, not me.
## real_home: - **Marker:** /var/tmp/xschem_fixes/r4v1s/marker_start, created at the start.
- **Manifest:** `md5sum -c --quiet .../scratchpad/xschem_manifest_fixes.md5` gave rc 0 at the start, at mid-stage after the T1 pair, and at the end.
- **Find:** `find /home/analog/.xschem /home/analog/.claude/xschem_dev_display /home/analog/.claude/gui_test_gate /home/analog/.claude/xschem_owed /home/analog/.cache -newer <marker>` printed nothing, both at mid-stage and at the end.
- **No interactive xschem session:** the newest /tmp/Xschem.log* is still .4.
- **HOME:** every harness command ran under env -i with HOME set to a canary under /var/tmp/xschem_fixes/r4v1/canaries, and XSCHEM_OWED_DIR pointed inside that canary. The only processes carrying HOME=/home/analog were the wrappers, run.sh and `timeout`, which exec `env -i` straight away.
- **Displays:** the real ~/.claude/xschem_dev_display was never passed to anything, and :99 was never started, probed or stopped.
- **Kills:** only by pid, and only after /proc environ showed my tag (R4V1_FIXTURE, R4V1_ZOO or R4V1_DEC) or a canary HOME. No pkill was used.
- **Nothing left behind:** at the end there are no X locks on 190-194, no processes of mine, and no zoo dirs.
- **Main tree:** HEAD is still 32b6a9cd. I only read it and wrote receipts/S2c-R4-refute-safety.md. The ` M receipts/S1.md` in git status is not mine.
- **~/dev/xschem-op-wcard:** untouched.
- **Deviation:** one inline decoy test captured setsid's pid because the tool shell has job control. The real decoys were found by their environ tag and killed, and the test was redone with a script: all 3 decoys stayed alive.

########## regression: refuted=False
I could not refute round 4 (r4.patch) on regression, and there are no blocking findings. Everything below was measured; details are in /home/analog/dev/xschem-claude/doc/claude/outsider_fixes_batch/receipts/S2c-R4-refute-regression.md.

Setup:
- Fix tree: /var/tmp/xschem_fixes/r4v2/tree, which is main HEAD 32b6a9cd with the round-3 cumulative patch reversed and the round-4 cumulative patch applied. It is identical to HEAD + r4.patch, and all 13 touched files match r4b/tree.
- Base tree: /var/tmp/xschem_fixes/r4v2/base, which is HEAD itself, because HEAD already carries round 3 as 7a46275f. The brief said "HEAD + the r3 patch"; that is the one deviation.

T1 in the main-tree shape (DISPLAY=:195, a canary copied from the real ~/.xschem, the fork ngspice copied in) was 87/86/0 in all 5 fix runs and in base:
- attach to a dev display on :196 that the fix's own `devdisplay.sh start` brought up (776 s); a sampler saw the display cases run on :196;
- base, attach on :197, run at the same time (760 s);
- auto-start from the user's real state-dir shape, with dead xvfb.pid and wm.pid. The started display had HOME = the canary and none of the harness variables, and the canary changed only in the files D13.2 allows;
- a stranger run on the private :100, run at the same time and in the same tree as the auto-start run. The "another run is live" banner printed once;
- the checkout placed inside the canary HOME, which is the user's real layout. 0 of 1.27 million inotify events fell outside the checkout.

Per case:
- All 86 verdict blocks are identical between fix and base.
- 85 of 87 RESULT lines are identical. The two that differ only gained checks: test_home_isolation 116 against 111, and test_home_isolation_sh 90 against 87.
- No flake appeared, so nothing needed the 3× rerun.

No suite lost checks:
- run_suites over all 405 suites, fix and base at the same time: 403 of 405 have identical verdict and RESULT text, and the two that differ are the gains above. The verdict counts match exactly (349 pass, 17 no result, 18 skip, 14 fail, 7 timeout), and the fails and timeouts are the same pre-existing suites.
- The 12 standalone .sh suites are identical between fix and base.
- test_devdisplay.sh passed with 53 checks against base's 43, and every base check is still present.
- test_ase_migrate.py passed with 151 checks in both.
- lookshot.sh and xarm.sh one both passed and left an empty canary empty.

Concurrency:
- 4 T1 drivers started together, 8 rounds (32 runs): 5 lost races were handled, the displays were always distinct, every run had 0 counted failures, and nothing was left behind.
- test_home_isolation, 4 at a time × 3 rounds: 12 of 12 passed with 116 checks. This covers the new rows H6d, H6e, H7b, L15, L19, G2 and G2b.
- test_home_isolation_sh, 4 at a time with one display number each: 8 of 8 passed.
- test_devdisplay.sh, 2 at a time × 3 rounds: 6 of 6 passed. At 3 at a time the new rows passed 6 of 6.
- The 1476 suite, 4 at a time: 4 of 4 passed.

Killed runs:
- T1 path: 0 of 55 trials leaked. These were timed kills from 0 to 2000 ms, self-kills, and trials pinned to one core with 2 CPU hogs. The worst took 5.1 s, no lock was left, and every reaper exited on its own. In 5 of the pinned self-kills `.xvfb.pid` was never written, and the server was still reaped through its tag.
- Shell path: 0 of 8 leaked, all gone within 1.3 s.

devdisplay.sh lifecycle on a canary state dir at :197: the fix passed 39 of 39. That includes stop killing its own WM while the server was frozen, restart leaving exactly one WM, and the user's real dead-pid state shape.

Sabotages: 13 in total.
- 8 went red, each on the row meant to catch it:

| sabotage | red row |
|---|---|
| SB | D22 |
| SC | D22 |
| SE | D17c |
| SG | D17 |
| SJ | H6e |
| SL | L15 |
| SL2 | L15 |
| SN | W10 |

- SA and SF stayed green, and both are real coverage gaps (see followups).
- SH, SI and SK stayed green but change nothing observable.

The only reds I saw anywhere were in older X rows of test_home_isolation_sh and in D6 of test_devdisplay.sh, and only when runs shared my 2-number xvfb-run pool. Base failed the same way (4 of 8 runs, against 3 of 8 for the fix), and both went green once each run had its own number. None of those rows are new in round 4.
## blocking:
## followups:
  * No test covers `devdisplay.sh stop` against a live server. Undoing the `_kill_wm "$xp"` call in cmd_stop (back to `_kill_pidfile wm.pid "$(_wm_name)"`, which matches by name only) left test_devdisplay.sh passing all 49 checks. A direct probe showed what that costs: with a live recorded Xvfb and wm.pid pointing at an openbox on another DISPLAY or with another HOME, the fix spares that openbox, but the undone version and base both kill it. D22 checks only the predicate and D21 only the dead-server case. Suggested row: plant D22's two decoys as wm.pid under a live server, run stop, and require both still alive.
  * Nothing tests the sweep's fallback to `.reaper_display`. Undoing it (reading only `display`) stayed green. A run killed inside `start` has only `.reaper_display`, and no test reclaims such a directory. The failure is the safe kind: a leftover survives rather than something wrong being killed.
  * The G2 launcher check scans the working tree, including untracked files, so T1's verdict can turn red because of scratch scripts left in a checkout. A read-only scan of the main tree today finds 3 offenders, all in the two files r4.patch fixes, so 0 once the patch is applied.
  * H6d treats a pid-counter wrap between its two forks ('wrapped') as a failure. The chance is about 1 in 100,000 per run; it could be reported as a skip instead.
  * Pre-existing and the same in base: the shell private display arm picks its display number with a race between checking and starting. xvfb-run -a has it, and so did my shim. With concurrent runs sharing a number pool, the older X rows (X1-X3, X5, X7, X7b, X8, X9) went red in 3 of 8 fix runs and 4 of 8 base runs, and test_devdisplay D6 in 2 of 6. With one number per run they all passed.
  * Pre-existing hygiene, same in both trees: test_gui_gate_revive.sh leaves a `sleep 300` decoy running with HOME set to the parent home.
  * Scratch for the driver to delete: /var/tmp/xschem_fixes/r4v2 (3.0 GB). I left the /tmp/xschem_emergencysave_* directories dated inside my window alone, because none of my outputs names them.
## real_home: - Manifest: `md5sum -c --quiet …/xschem_manifest_fixes.md5` returned rc 0 at the start, at the end, and again after I wrote the receipt.
- Changes in the real home: `find /home/analog/.xschem /home/analog/.claude/{xschem_dev_display,gui_test_gate,xschem_owed} /home/analog/.cache -newer /var/tmp/xschem_fixes/r4v2/.start_marker` printed 0 lines.
- Dev display state: the real state dir is unchanged (dated 2026-09-15 08:09), and :99 was never started, probed or stopped.
- Interactive xschem: the newest /tmp/Xschem.log is still .4.
- HOME: every run used env -i with HOME set to a canary or scratch directory under /var/tmp/xschem_fixes/r4v2. git, configure and make ran with HOME set to r4v2/ghome. XSCHEM_OWED_DIR always pointed into the canary.
- Main tree: I only read it, including a read-only G2 scan, and wrote one file, receipts/S2c-R4-refute-regression.md. I did nothing in ~/dev/xschem-op-wcard.
- Kills: only by pid, after checking the process's HOME in its environ. That covered my fixtures on :195-:197, my two CPU-hog processes and two decoy sleeps; no pkill.
- Leftovers at the end: none of my processes, no /tmp/.X19[5-9]-lock files, and no /tmp/xschem-test-home.* directories.

