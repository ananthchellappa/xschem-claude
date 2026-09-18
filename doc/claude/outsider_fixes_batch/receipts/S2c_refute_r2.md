# S2c round 2: integration, refuters (workflow wf_b143c826-370)

Verbatim. The driver's response is DECISIONS.md D17.

### I status: DONE
Round 2 is integrated, and Item 2 is proved again end to end on the final commit (r2i_4). Every shape passed its canary check, and every guard went red on its sabotage (or on the unfixed baseline) before going green.

Integration:
- The T and S patches applied with `git apply --3way` and no conflicts (they touch different files).
- The two helpers now follow one contract, D13 included. Where they disagreed or nothing locked them, I aligned them and added one row each:
  - nesting now uses the D13.6 owner-alive rule in both languages (L13);
  - both read the first field of `.owner` the same way (L14);
  - the custom-home banner no longer says "untouched" when the dir is inside the real HOME (L11b);
  - both sweeps kill a window manager only by its exact HOME (L10b);
  - two more symlink shapes are refused by both (L9).

The proof itself found three defects, fixed here and measured red first:
- **A (row H7):** T1's private display arm could take a display another run owns. Two runs picking the same number both claimed it in 3 of 30 synchronized pairs. The arm now accepts a display only if its lock file names the Xvfb it started.
- **D (row H6b):** openbox sometimes died at startup because the server reset between probe clients (12 of 360 starts without `-noreset`, 0 of 360 with). T1's private Xvfb now starts with `-noreset`.
- **B (row C5):** full_audit's `test_scratch_home_note` row C4 had been red since D13.11 added the skip-line echo. C4 now sets that one pattern aside, and C5 checks the echo.

T1 on the final code is 87 cases / 86 blocks / 0 counted failures, solo and in a concurrent pair. The canary stayed byte-identical in every shape except the auto-start shape, which is D13.2's allowed exception. Both crews' own sabotage sets, re-run on the integrated code, went red where expected (16 of 16 and 30 of 30).
### I patch: /var/tmp/xschem_fixes/r2i/final_item2_only.patch ce1e512325a91e3f058f00abc1a259d1
### I deviations:
 * The main tree's HEAD was 616110a6 at clone time, not 733e03ad (D14 changes only docs and the issue-stamp files), and it later moved to 52453f1e (docs only). The patch is the diff against 616110a6; apply --check is rc 0 at 52453f1e.
 * Nesting rule (R2T's deviation 2): I chose Tcl's rule, the D13.6 owner-alive state, and aligned the shell to it. The bare-pid rule could reuse a home that the sweep may delete. Row L13 locks it.
 * The shell's `.owner` first-field parse was aligned to Tcl's (a 1-10 digit pid with no leading zero); row L14.
 * The custom-home banner: D13.4 names only TMPDIR, but I applied its rule to a custom dir inside the real HOME in both languages (row L11b). Both crews had listed this as open.
 * Three fixes outside D13's list, each found by this stage's proof and each red first: A, the private-arm lock-identity check (H7); B, test_scratch_home_note C4/C5; D, T1's private Xvfb started with -noreset (H6b).
 * The code moved during the stage (r2i_1 to r2i_4). T1 solo, T1 pair, full_audit, the 14 pairs and the suites were re-run on r2i_4. Shapes 2 and 4-9 ran on r2i_1 and shape 11 on r2i_2. The later changes touch only T1's private-display start and test rows, not arming or HOME.
 * Display numbers outside 180-189 were chosen by the code under test, not by me: T1's private arm (:100-:102, hard-coded), test_home_isolation's fixtures (150-159) and test_devdisplay.sh (85-96). Every display I started, and every xvfb-run shim, was in 180-189. :99 was never touched.
 * Every run set XSCHEM_OWED_DIR to the canary's own sentinel ledger, which is stricter than a stranger's setup; the drain in shape 6 used a separate scratch ledger. Canaries also carry .Xauthority, Documents/, untitled~.sch and that ledger.
 * Sabotages ran in place in the integration tree or in a separate clone (sabtree), one at a time, with each file restored and checked by md5. Git status of every tree is clean at the end.
### I open_problems:
 * Issue 0448 (a parallel open_close job exiting 141, SIGPIPE) hit 3 of the 15 complete T1 runs in this stage, all under heavy concurrent load. It is not Item 2, but the stage-F gate should run solo and attribute any red by case.
 * `xvfb-run -a` numbers from :99 (R2S's open problem 1) and is not changed: xvfb_arm.sh's private path and test_devdisplay.sh's D6 can briefly hold :99 while the dev display is down.
 * `devdisplay.sh start` has the same probe-then-openbox reset shape as defect D, and `_ours` has defect A's shape (a live pid named Xvfb :N plus any server answering). Neither is in this batch's diff; both are recorded, not fixed.
 * Pre-existing, from R2S: test_devdisplay.sh's _cleanup removes the X lock by display number; wireedit/run_wireedit.sh is not armed when run standalone; a relocated owed.sh with no test_home.sh beside it runs its debt unarmed with a warning (the driver's call).
 * In a concurrent pair in one tree, the run that publishes a case's _output.txt first has that detail overwritten by the other run. That is why the third open_close FATAL's exit code was not measured.
 * Stage F still owes the CLAUDE.md scoping of the done-claim (D13.2) and the D12 issue files, with F14 re-attributed to DISPLAY being unset.
 * 18 /tmp/xschem_emergencysave_* directories are newer than my marker. Their times match my DISPLAY-unset T1 runs, test_file_menu_log and the kill shapes (inferred), but no output names them, so they were left in place.
 * Scratch for the driver to delete: /var/tmp/xschem_fixes/r2i (3.8 GB).

########## REFUTE safety: refuted=True
Verdict: REFUTED as worded. Every armed measurement the integration crew reported reproduces on my own build. What fails is the universal wording: several entry points documented in tests/headless headers (or in the current CLAUDE.md) still write into the tester's HOME, a relative TMPDIR leaves a directory behind, and one documented command kills processes it cannot identify. Tags: M = measured, R = read, I = inferred.

SETUP (M)
- Fix tree: /var/tmp/xschem_fixes/r2v1/fix = 52453f1e + istamp_s1fix.patch (7600660c) + r2i/final_item2_only.patch (ce1e5123). Built rc 0.
- Base tree: r2v1/base = HEAD + istamp. Round-1 tree: r2v1/r1 = HEAD + istamp + s2c_I/final_item2_only.patch. No-binary tree: r2v1/nobuild.
- Every run goes through tools/run.sh: env -i, DEVDISPLAY_NUM set, XSCHEM_OWED_DIR set, xvfb-run shimmed.
- Checks per run: a find+md5 snapshot, iwatch, and a new homesample.py that lists every process whose environ HOME is the canary.
- A realhome_watch.py ran from 11:28 to 11:58 for X or xschem tools started with HOME=/home/analog. It had 0 hits.
- Artefacts: r2v1/runs/<label>/{summary,snap.diff,out.txt,homeprocs.txt}.

REPRODUCED: canary byte-identical, 0 inotify events, 0 processes left (M)
- **T1** (t1_fix, DISPLAY on my :190):
  - `T1-RUN-END cases=87 blocks=86 counted_failures=0`, 612 s, wc -l 177, 87 Start / 87 Finish.
  - Private Xvfb :100. 0 tool processes ran with HOME=canary. 84 of 85 shared case RESULT lines are identical to base; 1476 is 37 vs 36.
  - With an EMPTY canary (t1_fresh): 87/86/0, and the canary stayed empty.
- **Base T1 red-first:** 85/84/0, but the canary changed:
  - clipboard 103→220 B; clean/short 35→147 B; geometry 5064→4834 B;
  - .xschem/op_annot, .claude/xschem_dev_display and .cache/openbox created;
  - a persistent :194 left running, which I stopped.
- **Developer shape** (t1_dev, empty state dir, DEVDISPLAY_NUM=192): 87/86/0.
  - The canary gained only the 5 state files and .cache/openbox.
  - The persistent Xvfb and openbox had HOME=canary and 0 XSCHEM_TEST_/GIT_CONFIG_/XAUTHORITY/XSCHEM_DEVDISPLAY_DIR variables. I stopped them.
- **PATH-only stub** (nobuild tree):
  - T1: 2716 calls, all with HOME=throwaway; the header says binary=<stub path>.
  - netlisting.tcl: 732 of 732 calls saw the throwaway.
  - run_suites, gated, full_audit, test_action_log, run.sh and run_nogui never fall back to PATH (FATAL, 0 stub calls).
- **full_audit, cwd = canary:** `392 pass 11 fail 0 crash/timeout 2 skip (total 405)`. The 11 fails are the same list as before. 1153 s.
- **run_suites, 5 writer suites, cwd = canary:** 5/5 PASS.
  - Base red-first: clipboard 103→107; clean/short 35→147; geometry 5064→5246; .cache/openbox created; the tester's untitled~.sch overwritten 102→219.
- **Also identical:**
  - `tclsh netlisting.tcl` (real binary);
  - all 8 standalone suites run from cwd = canary. test_devdisplay.sh ran through its shebang; `sh test_devdisplay.sh` refuses (Bad substitution, rc 2);
  - gated_xschem.sh and `xvfb_arm.sh --arm` from cwd = canary;
  - run.sh and run_nogui.sh. Base run_nogui red-first: 412 events;
  - an empty-canary run_suites;
  - HOME itself a symlink to the canary.
- **owed.sh drain**, one shell debt and one Tcl debt, scratch ledger: both cleared, canary identical.
  - Base red-first: clipboard 103→201; geometry 5064→5241; .claude/gui_test_gate created; untitled~.sch DELETED; a wish panel left running, which I killed.
- **Attach** (fixture :193 -audit, seeded state dir): "ATTACHED", canary and state dir identical, and the clients appear in the server's audit log.
- **D10 readers with fixtures and the fork present:** vcd_read 187, time_base 124, launch_context PASS, converge 76, sp 61, cosim 342, canary identical.
- **devdisplay.sh view/--stop:** writes only vnc.log in the state dir.
- **kill -9:**
  - T1 in the display arm: Xvfb and openbox gone in 1765 ms, lock removed. The leftover home was swept by a later arm (M: gone).
  - T1 with XSCHEM_TEST_KEEP_HOME=1: gone in 1759 ms, and .keep was written at arm time.
  - run_suites after the handoff: gone in 725 ms, and the trap deleted the home.

ROUND-1 SAFETY RECIPES: RED on the round-1 build, GREEN on the fix (M)
- **R5b**, forged dead throwaway naming a foreign live Xvfb and a decoy: r1 killed my fixture Xvfb (sh and Tcl) and the decoy (Tcl). The fix kept both alive, lock intact.
- **R5d**, handoff without exec: r1 child deleted the parent's live home. The fix refuses ("not running xvfb-run") and the home survives.
- **R5e**, KEEP + kill -9: r1 swept it (sh and Tcl). The fix keeps it.
- **R4**, XSCHEM_TEST_HOME = a symlink to the real HOME: r1's Tcl wrote a probe into the real home. The fix refuses (sh rc 2, Tcl rc 3). Variants b and e (trailing slash, `..`) are also refused.
- **R5c**, live bwrap --unshare-pid run with ns-pid 3003 (dead on the host): r1's host sweep deleted it (sh and Tcl). The fix leaves it alive in both.
- **REAL_HOME forgeries** (1, empty, relative, a file, a throwaway, inside a throwaway): refused, sh rc 2 / Tcl rc 3. HOME unset, empty or relative: the shell refuses.
- **R1d, still RED:** see problem 3.

WHAT REFUTES THE CLAIM: see problems. Items 1-4 and 7 are measured writes or kills through documented entry points, or through a TMPDIR setting. None is in the integration receipt's exception list. Items 1, 2 (netlist_diff) and 7 are not in its open problems at all. Everything D8/D13 armed holds.
### problems:
 * MEDIUM (M): tests/headless/lookshot.sh is documented in its own header ('lookshot.sh out.png pose.tcl ...'), is unarmed, and appears in no receipt or HOME map. Run with HOME=canary and LOOK_DISPLAY=:193 (runs/lookshot), it changed the canary: `< ./.xschem/geometry f 5064` / `> ./.xschem/geometry f 5059` (a saved window position evicted, the F7 class), and it created `./.cache/xschem-winshot/{build.log,winshot}` (21792 B). winshot.sh defaults its build cache to $HOME/.cache/xschem-winshot (R, line 22).
 * MEDIUM (M): tests/netlist_diff/netlist_diff.sh (header-documented, never armed, not recorded anywhere) and tests/headless/wireedit/run_wireedit.sh (recorded by R2S as unarmed) run xschem with the tester's HOME: 2 and 58 xschem processes with HOME=canary. On a FRESH home both CREATE `./.xschem d 700` and `./.xschem/xschemrc f 34595` (runs/fresh_netlistdiff, runs/fresh_wireedit). A seeded canary cannot see this, because .xschem already exists: runs/hr_* were identical. So the D11 seeded-canary proof is blind to first-run creation under the real HOME. My empty-canary runs of the ARMED drivers (fresh_rs, t1_fresh) stayed empty.
 * MEDIUM (M; D9's known exception, but the current CLAUDE.md still documents it and stage F has not rewritten it): the bare suite command `./src/xschem --nogui --pipe -q --script tests/headless/test_crossview_paste.tcl` with HOME=canary changed `< ./.xschem/.clipboard.sch f 103` to `> ... f 198` and printed NO note. Only 191 of 405 suites source scratch.tcl, so the note D9 relies on never appears for the other 214. Round-1 recipe 1d reproduces unchanged. xschemtest.tcl (D13.1) is likewise unarmed (R).
 * LOW-MEDIUM (M): a RELATIVE TMPDIR breaks the shell arm. test_home.sh exports HOME as a relative path (`HOME=tmp/xschem-test-home.<pid>.XXXXXX`). D13.3's `cd "$REPO"` then re-points it, so the run fails: run_suites NORESULT 'binary never reported' (rc 1), and gated_xschem.sh rc 1. The cleanup then refuses: '!! test home: NOT deleting tmp/xschem-test-home.1708632.A41plt: its .owner names pid <none>'. The directory is left behind in the caller's cwd. With cwd = HOME that is permanent litter in the real home: `> ./tmp/xschem-test-home.1708632.A41plt d 700`, plus `.owner` and `.xschem` (runs/se_rs, runs/se_gated). Outside HOME it is a write into a cwd outside the checkout. Tcl normalizes TMPDIR and is unaffected (R). Fix: make root absolute (`root=$(cd "$root" && pwd)`) before mktemp.
 * LOW (M, forgery): the nesting test does not require HOME to sit under the temp root, although the fresh arm and _th_takeover both do. Measured: HOME=<canary>/xschem-test-home.1.forged, with .owner '1 - -' or my live shell's pid, plus XSCHEM_TEST_REAL_HOME=<canary>, is accepted as nested by BOTH languages. The run then uses a directory inside the real home as HOME. The shell banner says 'the throwaway lives under your HOME because TMPDIR does', which is false here: TMPDIR was elsewhere. Tcl prints nothing (runs/exp/nest).
 * LOW (M, opt-in): XSCHEM_TEST_HOME=<dir> whose `.xschem` is a symlink into the real home (for example a symlinked 'copy of someone's configuration'). The banner says 'custom ... (never deleted; your HOME is untouched)' while the real clipboard is overwritten: `< ./.xschem/.clipboard.sch f 103` / `> ... f 198` (runs/custom_symx). D13.5 resolves only the custom dir itself.
 * MEDIUM (M, pre-existing, not in the diff; contradicts 'nothing the harness kills ... can be anything but its own'): `tests/headless/devdisplay.sh stop`, documented in CLAUDE.md, kills whatever pids the state dir's xvfb.pid/wm.pid/vnc.pid name, with no identity check. Two unrelated `sleep` decoys named in a canary state dir were both killed ('devdisplay: stopped :191'; D1 alive=n, D2 alive=n), and it also does `rm -f /tmp/.X$NUM-lock` by number (R). The user's real state dir today names xvfb.pid 1116 and wm.pid 1135, both dead (M, read-only), which are exactly the low pids a reboot hands to other processes.
 * LOW (R, recorded by the crew itself): test_devdisplay.sh _cleanup does `rm -f /tmp/.X$NUM-lock /tmp/.X${FOREIGN:-999}-lock` by NUMBER, on EXIT and on INT/TERM (and on INT/TERM the suite then carries on). owed.sh add/drain write the real ledger $HOME/.claude/xschem_owed by design (D13.1), which the claim's exception list does not name. TMPDIR inside HOME still creates and deletes the throwaway under the real HOME (D13.4 accepted). The banner is now truthful in both languages (M, exp/sf case d).
 * NOTE (M, not attributed to me): at about 11:28, two short-lived `openbox` processes (2183607, 2183735) had HOME=/home/analog and DISPLAY=172.20.160.1:0, the user's real screen. They were gone before I could read their parent. Every run of mine used env -i or an explicit HOME/DISPLAY. The environment matches a Claude tool shell's, so they were probably another session's `openbox --version`-style call (I). The real HOME was unchanged, and realhome_watch saw 0 more from 11:28 to 11:58.
 * Hygiene (M, pre-existing): the hand-run test_gui_gate_batch.sh and test_gui_gate_revive.sh leave decoy `sleep 60` and `sleep 300` processes with HOME=canary; they expire on their own. Both hand-run suites run wish panels, and test_owed.sh runs git, under the tester's HOME, unarmed. None of them wrote anything (canaries identical). gate_batch reported `fails=2` (V4/V7/V8 brake rows) in my run; that is not a safety issue.
 * Method caveats: my canaries live under /var/tmp, which spawn_reaper treats as a temp root, so test_gui_gate_batch R8 printed skip rather than exercising reaper_init on a real /home path. Code under test chose displays outside 190-194: T1's private arm :100-:103, the test_home_isolation fixtures :150-:164, test_devdisplay :85-:96 and gate_batch :101-:160. My xvfb-run shims started at 191-193, and full_audit's reached :194. My one stray openbox attempt on :194 (full_audit's -auth server) could not connect and exited; full_audit's result was unchanged (I).
### real_home: Start marker: /var/tmp/xschem_fixes/r2v1/.marker_start, 2026-09-18 11:02:48. `md5sum -c --quiet .../xschem_manifest_fixes.md5` gave rc 0 at the start, again at 11:28 and again at the end (11:58).

`find /home/analog/.xschem /home/analog/.claude/xschem_dev_display /home/analog/.claude/gui_test_gate /home/analog/.claude/xschem_owed /home/analog/.cache/openbox -newer <marker>` printed nothing, both at 11:28 and at the end. ~/.cache/openbox/openbox.log is still dated 09-17 06:48.

A wider sweep of /home/analog -newer marker, pruning dev/ and Claude's own dirs, showed only Claude Code files: .claude.json, its backups, .local/bin/claude and versions/2.1.277, the skills manifest and .last-update-result.json.

The only new /tmp/Xschem.log* files were .5 and .6 (11:22:21 and 11:22:26). By content ('launch: .../r2v1/fix/src/xschem ... gated_fix/mytest.tcl' and './src/xschem ... test_crossview_paste.tcl' with cwd r2v1/fix) they came from my gated_fix and xarm_fix runs, so I removed them, so they cannot be read as a user session. The newest remaining is .4 (09-17 23:35).

Every run's HOME was a canary or scratch dir under /var/tmp/xschem_fixes/r2v1. XSCHEM_TEST_REAL_HOME was never /home/analog, and the fork ngspice was COPIED into canaries/d10. owed.sh always had XSCHEM_OWED_DIR set to a scratch ledger (r2v1/ledgers/* or a canary's own).

Displays:
- :99 was never started, stopped or probed. DEVDISPLAY_NUM was 192, 193 or 194 on every run, and lookshot had LOOK_DISPLAY=:193. The revive suite's DISPLAY=:99 runs under a stub wish, and gate_batch R7 only scans /proc (R).
- My fixtures were :190-:193, plus an attempt at :194. All were stopped by pid. The auto-started :192 (t1_dev) and base's leaked :194 were stopped with devdisplay.sh stop against their canary state dirs.
- The round-1-build sweep killed my own fixture :191 once, as the intended red-first, and I restarted it.

At the end: no /tmp/.X19[0-4]-lock remains, no process has a HOME under r2v1 or a throwaway my runs named, and no xschem-t1-reaper or --reap of mine is running. The one --reap left belongs to r2v2. My kept KEEP home (/tmp/xschem-test-home.2419529.jMYYur) is deleted.

About 20 /tmp/xschem_emergencysave_* dirs are newer than the marker. They are mixed with r2v2's concurrent runs, and 0_examples_top_dfdafbaddd (11:45) is probably my lookshot kill (I). None was named by my output, so all were left in place.

Main tree: only read, cloned and apply-checked. `git status` matches the start snapshot, HEAD is 52453f1e. ~/dev/xschem-op-wcard was not touched.

Scratch for the driver to delete: /var/tmp/xschem_fixes/r2v1 (1.8 GB).

########## REFUTE regression: refuted=True
VERDICT: refuted, on one clause. I measured that a killed run can leak its private display with no time limit. Every other clause reproduced. Two narrower gaps also turned up. Tags: M = measured, R = read from source, I = inferred.

SETUP (M)
- HEAD was 52453f1e (commits after 733e03ad changed docs only).
- /var/tmp/xschem_fixes/r2v2/tree = HEAD + istamp_s1fix.patch (md5 7600660c) + final_item2_only.patch (md5 ce1e5123).
- /var/tmp/xschem_fixes/r2v2/base = HEAD + istamp_s1fix.patch only.
- tree2 is a copy of tree, used for the concurrent pairs. sabtree is identical to tree on every patched file, used for sabotages. All four built with rc 0.
- Every run went through tools/run.sh: env -i, HOME set to a seeded canary, find plus md5 snapshots, inotify, and a leftover scan.
- Canary kinds:
  - realcopy: a relocated copy of the real ~/.xschem, .gitconfig and .ngspice_history, plus a copied fork ngspice. This is the "main-tree shape".
  - fork: a stranger canary with the fork copy.
  - An empty dev state dir and gate dir were added where the shape needed them.

T1 (M)
- **A, main-tree shape, DISPLAY set:** DISPLAY=:195 for tree and :196 for base; realcopy canary with a dev state dir.
  - tree: `T1-RUN-END cases=87 blocks=86 counted_failures=0`, 622 s, 87 Start / 87 Finish, wc -l 177.
  - base: 85/84/0, wc 173.
  - All 84 shared blocks identical. The last RESULT line is identical in 84 of 85 shared case logs; the exception is 1476, 37 vs 36.
  - The D10 suites match: converge_1459 76, sp_1452 61.
  - Auto-start used :197. Its Xvfb and openbox have HOME = the canary. Their environment holds only DEVDISPLAY_NUM, DISPLAY, HOME, LANG, LOGNAME, PATH, PWD, SHELL, SHLVL, TERM, USER, XSCHEM_OWED_DIR and _. There is no XSCHEM_TEST_*, no GIT_CONFIG_* and no XSCHEM_DEVDISPLAY_DIR.
  - The canary changed only in the state files and .cache/openbox (17 events).
- **D, attach (second run on the same canaries):** tree 87/86/0. The canary, state dir included, is byte-identical with 0 events. 12 xschem pids ran with DISPLAY=:197. Base 85/84/0, identical per case.
- **B, DISPLAY unset, fork canary:** tree 87/86/8 (wc 185) against base 85/84/8 (wc 181), identical per case.
  - The only counted lines are the 4 F14 suites (signal 11 plus HARNESS).
  - Check counts identical except 1476.
  - The tree canary is identical. It ran on private Xvfb :100.
- **Trailer arithmetic:** 177 = 2 + 86 + 86 + 3; 179 with 2 counted lines; 185 with 8.

CONCURRENCY (M)
- **T1 pair 1** (separate fork canaries, DISPLAY :195): both 87/86/0. Private displays :102 and :101. Canaries identical. The peer banner was shown.
- **T1 pair 2** (one shared developer canary, auto-start race on :199):
  - A: 87/86/0.
  - B: 87/86/2. The two lines are `test_ase_optier_0963` X7 (ngspice rc=1 "Timestep too small", raw=-1bytes) plus its HARNESS line.
  - Attributed to the documented issue-1455 X7 flake (I): X7 uses PATH ngspice and its own scratch rundir, not HOME, and it is recorded failing 2 of 3 runs inside run_regression.
  - Only one persistent Xvfb existed, and only the D13.2 files changed.
- **Standalone pairs, bare command, DISPLAY unset:**

| suite | runs | result |
|---|---|---|
| test_scratch_home_note | 40 | ALL PASS (21) every time |
| test_home_isolation_sh | 40 | ALL PASS (82) every time |
| test_regression_concurrency_1476 | 20 | ALL PASS (37) every time |
| test_home_isolation | 40 | all ALL PASS; 39 at 104 checks, 1 at 103 (H3 skipped) |

  - All canaries were identical and no process was left.
  - In 4-way concurrency, 20 runs were all ALL PASS, but H3 skipped in 10 of them ("no free display number in 150-159").

SABOTAGES (M; one at a time in sabtree, md5 restored)
The no-op control was green (104, 82, 21).

| id | sabotage | red rows |
|---|---|---|
| V1 | shell reaper exits without killing | X7 |
| V2 | Tcl reaper polls every 60 s | H6 |
| V4 | shell snapshot taken after the carry | K4, K5, L2b |
| V5 | gated_xschem.sh does not cd | C2 |
| V5b | run_suites.sh does not cd | C1 |
| V6 | drain's shell debt runs unarmed | W3, W8 |
| V7 | the note is always printed | N2, N5, N6 |
| V8 | test_real_home ignores XSCHEM_TEST_REAL_HOME | R1, R5 |
| V9 | Tcl sweep ignores age | B2a, F2, F6, L1z, L7, L13 |
| V3 | the counted HARNESS FAIL for an installed Xvfb that will not start becomes an uncounted NODISPLAY line (D8 step 4) | **none**: test_home_isolation 104 and 1476 37 stayed ALL PASS |

COVERAGE (M)
- **run_suites.sh over every test_*.tcl**, realcopy canaries, 405 vs 402 suites:
  - All 402 shared suites have the same verdict and RESULT text, except 1476 (expected) and test_hi_descend.
  - test_hi_descend was NORESULT in tree and TIMEOUT in base. Re-run 3 times in each tree it was NORESULT 3 of 3 in both, so the base hang was a one-off.
  - Tree canary identical, 0 events.
  - skip: lines were echoed under 4 verdicts (ase_cosim REF12, op_annot W23, vcd_read A/RP, vcd_time_base REF). Their check counts equal the base's.
- **The bare documented command over the whole corpus**, with a display and with --nogui:
  - Identical except 1476 once reruns were done. Two differences were fixed-/tmp-path crosstalk between my own parallel tree and base streams; 3 of 3 reruns were identical.
  - The tree printed the note in 200 and 181 suites respectively, and it changed no verdict.
- **Standalone .sh suites and tcases:** the 7 --arm suites, test_devdisplay (39) and test_owed (365) have the same rc, ok count and FAIL count in tree and base. The tree canaries were identical. create_save and netlisting run standalone are equal (740 jobs).
- **Shell attach:** run_suites attached to fixture :199 through the canary's state dir. Both suites ran on :199, and the canary was identical.

OWED (M)
- 22 non-drain commands were run with 3 ledger modes: absolute XSCHEM_OWED_DIR, unset, and relative. rc, stdout, stderr and ledger contents are identical to base, after normalising epoch, pid and clone name.
- **drain** (one shell debt, one Tcl debt, gate live on :199): both passed and were cleared.
  - inotify on the given ledger shows only cleared.log and the 2 deletions.
  - The canary is identical with 0 events and 0 processes left.
  - No xschem_owed directory appeared elsewhere.
  - Base: a gate dir was created in the canary and a wish panel was left running. I killed it by identity.

KILL -9 (M)
- **After the reaper is up:** Tcl cleaned up in 4.82 s (3 of 3). Shell cleaned up in 4.0, 2.67 and 1.24 s. That reproduces the claim.
- **Tcl, before the reaper.** I killed T1 the instant .xvfb.pid appeared.
  - Xvfb :100 was alive at 60 s with no reaper.
  - It lived about 5 minutes, until a later arm's sweep killed it.
  - The window is 130–138 ms (6 samples).
- **Shell, before the reaper.** I killed the run_suites pid (by then xvfb-run) 0.06–0.16 s after start.
  - Xvfb was alive at 60 s in 3 of 3 runs.
  - The window is 98–103 ms (6 samples).
  - Once the throwaway was more than 300 s old, the sweep printed "swept dead throwaway(s): xschem-test-home.1997347.29mww6" and left Xvfb :199 running with HOME set to that deleted directory.
  - Nothing can ever collect it. The shell path records no .xvfb.pid (R), and the base leaks in the same way.
  - Unshimmed, `xvfb-run -a` numbers from :99. That is the orphan shape this batch exists to remove (I).
### problems:
 * REFUTING (M): 'a killed run leaks no display beyond ~10 s' fails in the window before the reaper starts. On the shell private path, kill -9 of the pid the tester started, within ~100 ms of Xvfb starting (98-103 ms, 6 samples), leaves that Xvfb running for good (3 of 3). The launcher's _xvfb_start_reaper returns early once xvfb-run is dead. Nothing records .xvfb.pid on this path, so the next sweep deletes the throwaway and leaves an Xvfb whose HOME is a deleted directory (measured on :199). Unshimmed it would be :99 (I). The Tcl private arm has a 130-138 ms window between recording .xvfb.pid and starting the reaper. A kill there left Xvfb :100 alive at 60 s, and it survived about 5 minutes, until a later arm's sweep. Fix: start the shell reaper before, or together with, the WM claim, or record the xvfb-run server in the throwaway so the sweep can kill it. Start the Tcl reaper right after the exec, not after the up-check.
 * GAP (M): sabotage V3 turns D8 step 4's counted 'HARNESS ... Xvfb is installed but no display could be started: FAIL' into an uncounted NODISPLAY line (the issue 0891 class). Nothing goes red: test_home_isolation stays ALL PASS (104) and 1476 ALL PASS (37). No row covers an installed Xvfb that will not start.
 * CONCURRENCY COVERAGE (M): test_home_isolation's display rows reserve fixture numbers from 150-159 only. With 4 concurrent instances, H3 skipped in 10 of 20 runs ('no free display number in 150-159'), and every run still read ALL PASS (103 vs 104). With 2-way pairs it was 1 of 40, while other load was live. In T1, summarize_all drops skip lines, so the row vanishes without a trace. It is not a false red, but the check count is unstable under concurrency.
 * ATTRIBUTED, not Item 2 (I): in T1 pair 2 (a shared developer canary), run B counted 2 lines. Both are test_ase_optier_0963 row X7 (ngspice rc=1 'Timestep too small', raw=-1bytes) plus its HARNESS line, which is the documented issue-1455 X7 flake. X7 uses PATH ngspice and a per-suite rundir, not HOME. It passed in the other 9 T1 runs this session. The stage-F gate should still attribute any red by case.
 * MINOR (M): in the tree, owed.sh drain prints the 'test home: throwaway' banner twice for a shell debt: once from the drain's subshell arm and once from the suite's nested --arm. Cosmetic.
 * DEVIATIONS: (1) The code under test picked its own display numbers outside 195-199: :100-:102 (T1 private arm), 150-161 (test_home_isolation fixtures and _sh's xvfb-run), 85-96 (test_devdisplay). Once, xvfb-run -a moved to :200 because 198 and 199 were taken (my kill test); I killed that server by identity. (2) Extra clones: tree2 and sabtree. (3) Early on I ran one broad `pkill -x sleep -u analog -P 1` to reap my own orphaned test sleeps. It could also have matched other orphaned sleeps whose parent is pid 1. (4) I edited bare1.sh while it was running, which lost one index line (test_ase_plot); I reran it, 151 checks in both trees. (5) My parallel tree and base bare streams shared fixed /tmp paths, which produced 2 false diffs; I reran them 3 times. (6) XSCHEM_TEST_XVFB_BASE was left at its default of 160. (7) I removed 42 /tmp/xschem_emergencysave_* directories named in my own outputs. 37 others newer than my marker were left. (8) Scratch for the driver to delete: /var/tmp/xschem_fixes/r2v2 (3.7 GB).
### real_home: - Marker: /var/tmp/xschem_fixes/r2v2/.start_marker, touched 2026-09-18 11:03:02.
- Manifest: `md5sum -c --quiet …/xschem_manifest_fixes.md5` gave rc 0 at the start (11:03) and at the end (13:01).
- Find: `find /home/analog/.xschem /home/analog/.claude/xschem_dev_display /home/analog/.claude/gui_test_gate /home/analog/.claude/xschem_owed /home/analog/.cache/openbox -newer <marker>` printed nothing, rc 0, at the end.
- No interactive xschem: the newest /tmp/Xschem.log* is .4, from 09-17 23:35.
- HOME for every run was a canary or scratch dir under /var/tmp/xschem_fixes/r2v2. Nothing ran with HOME=/home/analog. XSCHEM_TEST_REAL_HOME was never set to it: /home/analog/.xschem, .gitconfig, .ngspice_history and the fork ngspice were only COPIED into canaries, with paths relocated.
- owed.sh always ran with XSCHEM_OWED_DIR set to a scratch or canary ledger.
- :99 was never started, stopped or probed by me. DEVDISPLAY_NUM was 197, 198 or 199 on every run, and xvfb-run was shimmed to 197, 198 or 199. There is no /tmp/.X99-lock at the end. ~/.claude/xschem_dev_display and ~/.claude/gui_test_gate were only read.
- At the end: no /tmp/.X*-lock at all, no /tmp/xschem-test-home.*, and no process with a HOME or cmdline under r2v2. My fixtures :195-:199 and the persistent displays the tests auto-started were all stopped by pid or with devdisplay.sh stop against the canary state dirs.
- Main tree: only read (git status and log). HEAD is 52453f1e and the status is the same 11 lines. Nothing was touched in ~/dev/xschem-op-wcard.
