# S2c round 1: refuters and critic (workflow wf_b0cf8eaa-380)

Verbatim. The driver's response is DECISIONS.md D13.

==================== S2c completeness critic ====================
## refuted: True
## reasoning: Verdict: Item 2 is not done as PLAN defines it. The code under D4-D8 is complete, and the crews' proof is honest. But PLAN's done-when ("a documented test run touches nothing under the tester's real HOME ... and T1 stays at ZERO") fails in three ways. (a) I measured one documented command that still writes the real HOME. (b) One D11 shape fails its own pass condition. (c) T1 at ZERO in the main tree is unproven, and I measured that the "F14 fresh-clone segfault" label every receipt uses is wrong. Tags: M = measured, R = read.

Integrated tree checked: /var/tmp/xschem_fixes/s2c_I/tree. `git diff HEAD` is byte-identical to final.patch (md5 7f07f0e3…) (M). In the main tree, `git apply --check final_item2_only.patch` returns rc 0, and the reverse check of the issue-stamp files returns rc 0 (M, read-only).

PER CLAUSE
- **D2, D4, D5 (IMPLEMENTED, PROVEN).**
  - Tcl: `t1_arm_home`, called at source time at the end of the new block in tests/test_utility.tcl. It is a no-op inside xschem (`info commands ::xschem`).
  - Shell: tests/headless/test_home.sh `test_home_arm`, sourced before `. xvfb_arm.sh` in run_suites.sh, full_audit.sh (inside the AUDIT_LIB_ONLY guard) and gated_xschem.sh.
  - Handoff: `test_home_handoff` runs right before `exec xvfb-run`. The owner deletes through `t1_home_release` (after the trailer, plus a wrapped `exit`) and `_th_cleanup`, with all of D5's re-checks. The sweep kills a recorded `.xvfb.pid`.
  - Proof: the sabotage matrices (T 40/41 plus a no-red control, S 26/26, L 11/11) and T's kill test (receipts).
- **D6 (IMPLEMENTED).** `T1-RUN-BEGIN … home=… binary=… canonical=` goes through `t1_hdr_word`, and 1476 V4b passes (37).
  - One gap, M: in the F10 shape (no src/xschem), `xschem_cmd` is the bare word `xschem`, so the header says `binary=xschem`, not a path, while `auto_execok` resolved it to my fake binary.
- **D7 (IMPLEMENTED, PROVEN).** The carry block, `t1_home_preswitch_env` and gui_gate.sh `_gate_panel_env`, locked by rows A3, G1, H2, K4 and F7/F8.
- **D8 (IMPLEMENTED).** `t1_private_xvfb` numbers from :100 to :199. DISPLAY is set per exec through `$dd exec`. The private Xvfb is killed after the arm and again on release. NODISPLAY is used only for `noxvfb`; otherwise the case is a counted HARNESS FAIL.
  - Proven by H1-H4 plus s1_tree (private :100, 11 of 11 display cases green) and s6_attach.
- **D9.**
  - The scratch.tcl note is implemented and proven (U's N and C rows). The note also appears in 0 of the proof stdouts.
  - The CLAUDE.md spelling change is MISSING.
- **D10 (IMPLEMENTED).** All seven listed consumers read through `test_real_home` or `${XSCHEM_TEST_REAL_HOME:-$HOME}`, and U proved read-only.
  - R: a grep found no further HOME-fixture readers; the 15 other `env(HOME)` users are HOME switches or probe writes.
- **D11.**
  - Shapes 1, 2, 3, 4 and 6: canary byte-identical, no process left (I's receipt).
  - Shape 4 red-first, which I said was impossible, is now MEASURED by me. I made an unbuilt copy of base and of tree, put a fake PATH `xschem` in front that writes $HOME/.xschem, and ran `cd tests && tclsh netlisting.tcl` with HOME set to a canary.
    - base: recent_files went from 1 line to 729, and the clipboard was overwritten.
    - tree: the banner printed, the canary was byte-identical (find and md5), and the throwaway was removed. So F10 is closed.
  - Shape 5 FAILS the pass condition: `untitled~.sch` is left in the canary.
- **D12.** Recorded only; stage F must file the issues. Its F14 line is wrong (problem 2).

FINDINGS
- **Proven:** F6, F8 and F39 (canary identical in shapes 1-3; red-first s1_real/s2_real; base CHANGED). F10 (my red-first above). F36: no persistent Xvfb for strangers (s1_base leaked :188, s1_tree left 0), and no `.claude` or `.cache/openbox` in the canary.
- **F7:** proven for the three drivers and T1, but NOT for the standalone .sh suites (problem 1).
- **F25:** `.xschem` is pre-created with mode 0700 by both helpers (S row F4). The C race itself is untouched, which is outside scope.
- **F28:** partial. The display arm is now counted, the start error is printed, and the NODISPLAY text is fixed. The NOGOLD part and the 1481 skipped Finish line (NODISPLAY and HARNESS paths still `continue` before `Finish`) are neither fixed nor in D12.
- **F43:** not addressed. D12 records only `untitled~.sch`.

MY SCRATCH: /var/tmp/xschem_fixes/s2c_C (380 MB). It holds fbase and ftree (the unbuilt F10 trees), fakebin, shim, mt (a copy of the main tree without .git), and the *.out evidence files: f10_base.out, f10_tree.out, fml.out, ua_*.out, as_*.out, rs_vcd.out. The driver may delete it.
## problems:
  * 1 (most harmful; M): Standalone suites still write the real HOME. CLAUDE.md calls the 8 standalone tests/headless/test_*.sh 'armed entry points', but only D4's three drivers were armed. S flagged this (open problem 3), and I's integration claim dropped it. Measured on the integrated tree: `sh tests/headless/test_file_menu_log.sh` with HOME set to a canary (DISPLAY unset, xvfb-run shimmed to :199) rewrote the canary's .xschem/geometry, 882 to 1003 B. It added `<tmp>/fix.sch …` and re-stamped `untitled.sch 1110x761+808+0`, which is F7 again. It also created .cache/openbox, which is F36/F39. READ: test_action_replay.sh and test_action_log.sh launch GUI xschem the same way, and `owed.sh drain` runs shell-suite debts directly. Driver: arm test_home in xvfb_arm.sh's `--arm` entry (all of these re-exec through it; it needs the handoff), or record the exception in D4/D11 and CLAUDE.md with an issue.
  * 2 (M): T1 at ZERO in the main tree is unproven, and the F14 label is wrong. The four 'fresh-clone segfault' suites crash on --nogui exit when DISPLAY is UNSET, not because of a fresh clone. test_unused_attr_0970 in a copy of the MAIN tree (fresh HOME, and also a copy of the real ~/.xschem): DISPLAY unset gives `FATAL: signal 11` after UF28; DISPLAY=:199 (my Xvfb) gives `ALL PASS (67 checks)`. test_auto_specialize_1201 in the s2c_I clone: unset gives signal 11; :199 gives `ALL PASS (85 checks)`. Every proof ran with DISPLAY unset. The main-tree ZERO baseline (09-17 14:11) was presumably taken with DISPLAY set (INFERRED). Driver: run the stage-F gate with DISPLAY set to a private Xvfb, not :99 and not the user's screen. Otherwise expect exactly these 8 counted lines, and do not blame Item 2 for them. Correct D12's F14 entry and the issue file.
  * 3 (M, from I's shape 5c): D11's pass condition fails for shape 5, and D11 and D12 contradict each other with no written resolution. run_suites.sh and gated_xschem.sh do not pin their cwd; full_audit.sh does (`cd "$REPO"`, line 74). D9 makes run_suites.sh the documented single-suite command, so running it from ~ drops test_signal_short_nohier_0230's untitled~.sch into the real HOME, and it would overwrite a user's own ~/untitled~.sch. Driver: add a cd to the repo or the throwaway in both scripts, or amend D11 explicitly.
  * 4: Whether any suite runs fewer checks under the throwaway than under a real home is unmeasured. The per-case comparison used counted lines only, both base and tree used a stranger-like canary, and summarize_all drops `skip:` lines, so coverage lost to the throwaway is invisible. S2a already measured it once: converge_1459 dropped from 76 to 70 checks. Driver: after the stage-F T1, diff each case's `RESULT: … (N checks)` against the main tree's pre-patch per-case logs (tests/headless/*.log, 09-17 14:11, real HOME, 0 counted), e.g. converge_1459 must stay at 76.
  * 5 (M): D9's documented spelling hides all suite output, including D10's `skip:` lines. `run_suites.sh --nogui test_vcd_read` under the throwaway printed only `PASS … ALL PASS (156 checks)`. The skipped A and RP groups (31 rows, per U) are invisible, so D10's 'prints skip: rather than passing silently' is in practice silent through run_suites.sh and the T1 verdict. Driver: have run_suites.sh echo `skip:` lines, or document gated_xschem.sh (armed, passes output through, but no timeout) for reading a suite's rows.
  * 6 (READ): The stage-F gate conflicts with PLAN's standing constraint. The real state dir ~/.claude/xschem_dev_display exists, so under D8 step 2 the main-tree T1 runs `devdisplay.sh status`, then `devdisplay.sh start` with HOME=/home/analog, against the real :99. With today's healthy orphan, cmd_start exits 4 before it touches the state dir. If that server answers slowly, 0956's path deletes /tmp/.X99-lock, starts a competing Xvfb and writes xvfb.pid into the real state dir. Driver: pin DEVDISPLAY_NUM or XSCHEM_DEVDISPLAY_DIR for the gate, or accept this knowingly.
  * 7 (M): D6 says binary=<path>, but in the F10 case (no src/xschem, installed xschem on PATH) the header prints `binary=xschem`. That is the one case the field exists for. Fix: resolve it through `auto_execok` before calling t1_hdr_word.
  * 8 (docs, MISSING; stage F must rewrite CLAUDE.md):
- Lines 59-60, the single-case `tclsh netlisting.tcl` command: it now arms and prints the banner.
- Line 99, the 'running one directly: ./src/xschem --nogui --pipe -q --script tests/headless/<t>.tcl' advice: change it to the D9 spelling.
- Line 104, the T1-RUN-BEGIN field list: add home= and binary= before canonical=.
- Lines 160-236, the case counts. Currently 85 cases, 84 log lines, 70 hcases, 3/70/11, `wc -l`=173. They become 87 cases, 86 blocks, 72 hcases and 3/72/11 (I measured cases=87 blocks=86). The green `wc -l` must be MEASURED, not computed.
- Line 557, the 'green at 85' current-baseline sentence.
- Lines 241-262, the 1481 Start/Finish paragraph. 'a box where devdisplay.sh status is not alive prints 85/74' is now false: such a box runs the 11 display cases on a private Xvfb from :100. The skipped Finish lines now happen only when there is no Xvfb (NODISPLAY) or Xvfb will not start (a counted HARNESS FAIL).
- Lines 600-630, the dev-display section: the bare command now uses the real HOME and prints the D9 note, and 'the 8 standalone test_*.sh already need nothing' is false for HOME (problem 1).
- Line 926, the watchdog paragraph's bare command.
- Document the opt-outs, which D2 requires: XSCHEM_TEST_HOME=real|<dir> and XSCHEM_TEST_KEEP_HOME=1.
- Say that a tester who already has a dev-display state dir gets it auto-started with the real HOME, which writes the state dir and ~/.cache/openbox by design.
- Optionally note under 'A BARE xschem ON PATH' that T1 now contains the damage in a throwaway HOME.
  * 9 (docs/issues, MISSING): add an addendum to issue 0891's RULING recording D8's partial supersession. Its text still says 'No display -> an uncounted NODISPLAY line' and 'a surviving Xvfb is the documented intended state'. Update 1481. File the D12 issues with the corrected F14 cause. Record the unaddressed parts of F28 (NOGOLD, Finish asymmetry) and F43 (84-107 MB of gitignored output, the .actionlogs mkdir), which D12 omits. Update LEDGER and NUMBERING.
  * 10 (READ/INFERRED): other documented or harness commands are still unarmed and print no note: `xschem --script xschemtest.tcl`, which CLAUDE.md documents and which does not source scratch.tcl, and T2 tests/headless/run.sh and run_nogui.sh (--nogui; at least ~/.xschem/xschemrc litter on a fresh home). Record them or arm them.
  * 11 (low, the driver's call): the private arm scans :100-199 with no knob. Under XSCHEM_TEST_HOME=real the shell arm's openbox writes ~/.cache/openbox (I measured it in s2_real; it is opt-in). A TMPDIR inside the real HOME warns but does not refuse (D5 as written). test_scratch_home_note is not in T1; it runs only in full_audit (PASS in s3_tree).
## real_home_check: Start marker: /var/tmp/xschem_fixes/s2c_C/marker, 2026-09-18 05:02:24.
- **Manifest:** `md5sum -c --quiet …/xschem_manifest_fixes.md5` gave rc 0 at the start, mid-stage (twice) and at the end.
- **Find:** `find /home/analog/.xschem /home/analog/.claude/xschem_dev_display /home/analog/.claude/gui_test_gate /home/analog/.cache/openbox -newer <marker>` printed nothing.
- **Wider sweep:** `find /home/analog -newermt '2026-09-18 00:06'`, pruning dev/ and Claude Code's own dirs, showed only Claude Code files (.claude.json, backups, sessions, skills manifest). No test-shaped write reached the real home during this batch's runs.
- **Interactive xschem:** the newest /tmp/Xschem.log* is .4, from 09-17 23:35, so none was running.
- **HOME for every run:** a canary or scratch dir under /var/tmp/xschem_fixes/s2c_C (cb, ct, cs, cv, h1, h2, h3). I read /home/analog/.xschem only to copy it into h2.
- **Displays:** only my own Xvfb on :199 (started and killed by pid twice), plus xvfb-run shimmed to -n 199 inside test_file_menu_log.sh. There is no /tmp/.X199-lock left, and no process carries a HOME under s2c_C. :99 (1209045/1209133) was never started, stopped, viewed or probed; I set DEVDISPLAY_NUM=199 wherever a driver would otherwise default to 99.
- **Main tree:** only read, plus `git apply --check` (read-only) and an rsync copy out of it. No git state changes.
- **Not touched:** xschem-op-wcard.
- **Emergency-save dirs:** I removed the three my runs announced by name (aswv_dfbcedcfda, uapass_gbcfdbcega, uapass_cdabaefaeg). I left two empty ones, xschem_emergencysave_fix_ggcecaabde and fix_dacgfbbfbf (05:12:14 and 05:12:40), which are probably from my test_file_menu_log.sh run but cannot be proven by name. Others created at 05:13-05:15 (passgate, uapass, aswv) belong to another concurrent run and were left alone.

==================== S2c refute: safety ====================
## refuted: True
## reasoning: VERDICT: REFUTED as worded. The D11 core does hold: I reproduced every one of the integration crew's canary-identical measurements. What fails is the universal wording. Documented commands outside the armed set still write into the real HOME, and the sweep can kill or delete things that are not its own.

SETUP
- My clone: /var/tmp/xschem_fixes/s2c_V1/tree, at bc61cd05 with final.patch applied (md5 7f07f0e3...). Unfixed baseline: /var/tmp/xschem_fixes/s2c_V1/base (bc61cd05 + issue_stamp_main.diff). A third clone, /var/tmp/xschem_fixes/s2c_V1/nobuild, has the patch but no binary.
- Every run went through tools/run.sh:
  - env -i, DISPLAY unset, DEVDISPLAY_NUM=193;
  - HOME = my own seeded canary. Seeded per D11, plus .Xauthority and Documents/, with every mtime set to @1789000000;
  - find -printf plus md5 snapshots before and after, and iwatch.py over the whole canary;
  - a leftover-process scan by HOME.
- Artefacts: /var/tmp/xschem_fixes/s2c_V1/runs/<label>/{out.txt,snap.diff,iwatch.txt,procs_left.txt}

REPRODUCED (MEASURED)
- Shape 1, T1 (t1_tree): rc 0, 502 s, snapdiff=0, events=0, procs_left=0.
  - Own throwaway deleted; private Xvfb :100 killed.
  - Trailer: `T1-RUN-END pid=776440 cases=87 blocks=86 counted_failures=28`.
  - Base (t1_base): `cases=85 blocks=84 counted_failures=28`, canary CHANGED (clipboard 101->220, geometry, clean.spice/short.spice 33->148, .cache/openbox, .claude/xschem_dev_display) and a persistent :193 left running. I stopped it with devdisplay.sh stop against the base canary's state dir.
  - Per case, tree and base are IDENTICAL: 11 cases. The five D12 uppercase-path ASE reds plus related ASE cases, and the four F14 segfault suites. test_home_isolation and test_home_isolation_sh are at 0.
- Shape 2, run_suites.sh on 5 writer suites: default / --nogui / --logdir / -n 2 all give snapdiff=0 and events=0.
  - Base (rs_base) and XSCHEM_TEST_HOME=real (rs_real) both change the clipboard, geometry, clean/short.spice and .cache/openbox. That is the red-first.
- gated_xschem.sh: 0 in the tree. Base changes the clipboard, geometry and .cache/openbox.
- Shape 3, full_audit.sh subset (7 names): tree 0 / 0; base changed.
- Tcases run alone (create_save, open_close, netlisting): 0, and no throwaway left.
- PATH-only binary (nobuild clone, stub `xschem` first on PATH):
  - tclsh netlisting.tcl: 728/728 stub calls saw `HOME=.../xschem-test-home.1135557.jkpnqO`, 0 saw the canary; canary 0.
  - Mini T1: 3/3 calls saw the throwaway.
- Forgeries:
  - XSCHEM_TEST_REAL_HOME set to 1, empty, relative, a file, a throwaway, or a dir inside a throwaway: refused, shell rc 2 and Tcl rc 3, canary 0.
  - HOME unset, empty or relative: the shell refuses. Tcl arms with the passwd home (a getent shim pointed it at a canary); canary 0.
  - TMPDIR unwritable or nonexistent: refused. TMPDIR with spaces: works, canary 0.
  - XDG_* pointed into the canary: 0.
  - Stale throwaway whose owner pid is a live unrelated process: survives, in both languages.
  - Symlinks into the canary inside a dead throwaway: not followed, canary 0.
  - kill -9 of run_suites (after the handoff) and of T1 (in the display arm): the throwaway, Xvfb :100 and openbox are left. The next run within 300 s leaves them; after aging, the sweep kills the orphans and deletes the throwaway; canary 0.
- Missing xvfb-run, with DISPLAY unset and with DISPLAY set to my fixture: gate dir and panel stay inside the throwaway and the panel is killed; canary 0.

REFUTING MEASUREMENTS
1. Documented entry points that are not armed still write into the real HOME (the checks above never exercised them).
   - The standalone test_*.sh suites. CLAUDE.md calls them "armed entry points ... the 8 standalone test_*.sh", and their headers document `sh tests/headless/test_action_log.sh`. Seven of them route through `exec bash xvfb_arm.sh --arm`, which never sources test_home.sh. Measured:
     - All 7 I ran create `~/.cache/openbox/{openbox.log,sessions}`.
     - test_action_replay, test_file_menu_log, test_readonly_action_dispatch and test_devdisplay also rewrite `~/.xschem/geometry` (md5 1a2c6930 -> 74aab2ee etc.), evicting the tester's saved window positions for `/tmp/tmp.*.sch` and `untitled.sch`.
   - `owed.sh drain`, which CLAUDE.md documents, with a shell-suite debt: runs it via bare `bash "$path"`, and `.xschem/geometry` changed 4864 -> 4848 (runs/owed_drain_sh).
   - tests/headless/run_nogui.sh, the golden netlist harness named in the pin_rename_propagation spec, writes a 1.2 MB `~/.xschem/simulations/0_examples_top.spice` (runs/t2_run_nogui).
   - The bare suite command is D9's known exception. The note D9 relies on is printed only by the 191 of 405 suites that source scratch.tcl. test_crossview_paste run bare overwrote the clipboard (101 -> 198) with NO note.
2. Developer shape (MEASURED; by D8.2 design, but it contradicts the claim). ~/.claude/xschem_dev_display exists and the display is down, as after any reboot. A fixed T1 (t1_dev) then:
   - rewrites 5 state files there;
   - CREATES ~/.cache/openbox;
   - leaves Xvfb :193 and openbox running with HOME=real.

   With ~/.claude/gui_test_gate present and an explicit display (AUDIT_DISPLAY; owed.sh drain defaults to :0), run_suites writes 7 entries into the real gate dir and leaves a wish panel with HOME=real (runs/gate_shared).
3. TMPDIR inside HOME (common on HPC/EDA machines): the whole throwaway is created, written and deleted under the real HOME, with events and a changed tmp/ mtime. The note line is followed at once by "(your HOME is untouched ...)".
4. The Tcl helper accepts a symlink to the real HOME as XSCHEM_TEST_HOME=<dir>. It prints "custom ... (never deleted; your HOME is untouched)" and the write lands in the canary (.xschem/probe_wrote). The shell helper refuses the same input with rc 2 ("is your real HOME").
   - READ: the cause is that `file normalize` does not resolve the last path component. Section L does not cover this.
5. Deletes and kills that are not its own:
   - With cwd = HOME, run_suites.sh overwrites a pre-existing `untitled~.sch` (test_signal_short_nohier_0230) or deletes it (test_crossview_paste). That file is xschem's own autosave of unsaved untitled work (READ: save.c autosave). This is sharper than the integration crew's "leaves an untitled~.sch".
   - Both sweeps kill a live foreign Xvfb and openbox named in a dead throwaway's .xvfb.pid / .xvfb/wm.pid, checking only the program name. My fixture :190 was killed even though the forged .xvfb/display read :150. That needs pid recycling or forgery.
   - A LIVE run in another pid namespace that shares TMPDIR (bwrap --unshare-pid, owner ns-pid 1504) had its HOME swept by a host run: "swept dead throwaway(s): xschem-test-home.1504.j48dZk" while it was still running. The 300 s age gate does not protect it, because a live T1's top-level mtime is only its arm time (measured 159 s old mid-run).
   - A child handed XSCHEM_TEST_HOME_HANDOFF=<owner pid> without any exec takes ownership and deletes the parent's live home ("parent after child: HOME exists? NO"). READ: nothing in the tree exports the variable except xvfb_arm, just before its exec.
   - An XSCHEM_TEST_KEEP_HOME=1 run that is killed never gets its .keep, and is swept, in both languages.

DEVIATIONS
- HEAD was bc61cd05, not 4b9565ad.
- The clone is at the assigned uppercase path, so the D12 reds are present. They were attributed per case against a base in the same path shape.
- Displays outside 190-194:
  - T1's private arm, hard-coded, used :100 in 3 runs;
  - test_devdisplay.sh picks its own fixtures in 85-96;
  - test_home_isolation's H rows use :100/:150.

  :99 was never probed, because DEVDISPLAY_NUM was set on every run.
- xvfb-run went through a PATH shim (-n 191).
- One `pkill -f PROBE_HOLD` killed my own shell (the CLAUDE.md self-match trap). I then killed the leftover sleep by pid.
- Not measured: xschemtest via `--command xschemtest`; test_gui_gate_batch.sh (it probes and brakes processes); kill -9 in the pre-handoff window; another uid's entries (READ only: -O and st(uid) are checked).
## problems:
  * HIGH: Documented entry points were left unarmed and still write into the real HOME (MEASURED). The 7 standalone suites that re-exec via `xvfb_arm.sh --arm` (test_action_log, test_action_replay, test_file_menu_log, test_flylines, test_readonly_action_dispatch, test_readonly_guard, test_recent_launchlog) plus test_devdisplay.sh (run directly) create ~/.cache/openbox. Four of them also rewrite ~/.xschem/geometry. `owed.sh drain` runs a shell-suite debt as a bare `bash $path` and rewrites geometry. tests/headless/run_nogui.sh writes a 1.2 MB ~/.xschem/simulations/0_examples_top.spice. Candidate fix: arm test_home in xvfb_arm.sh's `--arm` entry, in owed.sh's .sh path and in run_nogui.sh. Evidence: runs/sa_*/snap.diff, runs/owed_drain_sh, runs/t2_run_nogui.
  * HIGH (scope of the claim): Developer shape, measured. When ~/.claude/xschem_dev_display exists and the display is down (every reboot), the FIXED T1 rewrites 5 state files there, CREATES ~/.cache/openbox, and leaves a persistent Xvfb and openbox running with HOME=real (runs/t1_dev). When ~/.claude/gui_test_gate exists and the display is explicit (AUDIT_DISPLAY=:0; owed.sh drain defaults to :0), run_suites writes 7 entries into it and leaves a wish panel with HOME=real (runs/gate_shared). Both are D7/D8 by design, so the claim must be scoped to strangers, or the auto-start and shared panel must be reconsidered.
  * MEDIUM: With TMPDIR inside HOME, the entire run is written, then deleted, under the real HOME (measured: events plus a changed tmp/ mtime). The warning line is followed at once by '(your HOME is untouched ...)', which contradicts it. Currently warn-only by D5.
  * MEDIUM: run_suites.sh with cwd=HOME OVERWRITES (test_signal_short_nohier_0230) or DELETES (test_crossview_paste) a pre-existing ./untitled~.sch, which is xschem's autosave of unsaved untitled work (measured, runs/cwd2_*). This is sharper than the receipt's 'leaves untitled~.sch'. Pinning run_suites' cwd to scratch would fix it.
  * MEDIUM (contract hole): Tcl t1_arm_home accepts XSCHEM_TEST_HOME=<a symlink to the real HOME> as custom, prints 'your HOME is untouched', and writes into the real home. The shell refuses the same input with rc 2. Cause: `file normalize` leaves the last component's symlink unresolved. Section L has no row for it (runs/f6_tcl vs f6_sh).
  * LOW-MEDIUM: Both sweeps kill a foreign live Xvfb and openbox named in a dead throwaway's .xvfb.pid / .xvfb/wm.pid, identified by argv[0] name only. The recorded .xvfb/display is ignored, which is weaker than devdisplay.sh's own _pid_is display check. This needs pid recycling (for example a stale TMPDIR on disk surviving a reboot) or forgery. Measured: fixture :190 and its openbox were killed by both the shell sweep and the Tcl sweep.
  * LOW: The sweep deletes a LIVE run's throwaway when that run is in another pid namespace sharing TMPDIR and uid (containers, bwrap/flatpak, CI), because its .owner pid looks dead from the host. Measured with bwrap --unshare-pid. A live T1's top-level mtime is only its arm time (159 s old mid-run), so the 300 s gate does not protect it. Recording the pid-namespace or boot identity, or refreshing the mtime, would close it.
  * LOW: The handoff trusts any process within parent/grandparent distance that carries XSCHEM_TEST_HOME_HANDOFF. A child given the variable without exec took ownership and deleted the live parent home (measured, runs/ho). No in-tree path leaks it today (READ).
  * LOW: An XSCHEM_TEST_KEEP_HOME=1 run that is killed never writes .keep, so its home is swept 300 s later in both languages. That is exactly the crash case where keeping it matters (measured).
  * NOTE for the stage-F gate: in the main tree, T1 will run `devdisplay.sh status` and `start` against the REAL state dir and probe :99 read-only. With the orphan up, start exits 4 without writing; measured in miniature with a foreign fixture on the state dir's number (runs/foreign, canary 0). If the orphan is stopped while the state dir remains, T1 will start a persistent :99 into the real home.
  * NOTE: 16 dead throwaways appeared in /tmp at 05:11:24-44 (.owner = own pid, dead, no .keep), during a window when other crews were also active. Not attributed. Under a private TMPDIR, my runs left none.
## real_home_check: Start, 05:02 on 2026-09-18: marker /var/tmp/xschem_fixes/s2c_V1/.start_marker touched, and `md5sum -c --quiet .../xschem_manifest_fixes.md5` rc=0.

End:
- The manifest check again gave rc=0.
- `find /home/analog/.xschem /home/analog/.claude/xschem_dev_display /home/analog/.claude/gui_test_gate -newer <marker>` printed nothing, rc 0.
- /home/analog/.cache/openbox: nothing newer.
- Newest /tmp/Xschem.log* is .4, from 09-17 23:35, so no interactive session was running.

What I touched and did not touch:
- Every run used HOME = a canary under /var/tmp/xschem_fixes/s2c_V1/canaries with DISPLAY unset. HOME-unset runs used a getent shim that returned a canary.
- Reads only from /home/analog: the fork ngspice binary was symlinked into a canary.
- :99 and its orphans (Xvfb 1209045, openbox 1209133) are untouched and still running. DEVDISPLAY_NUM was set on every run, so :99 was never probed.
- My fixture :190 and the auto-started :193 displays (base T1 and t1_dev, stopped with devdisplay.sh stop against the canary state dirs) are all stopped.
- No process with HOME in a V1 canary or V1 throwaway remains. The /tmp throwaways left are s2cv2's live T1s.
- Main tree: git status is identical to the start snapshot at HEAD bc61cd05 (only read).
- xschem-op-wcard was not touched.
- New /tmp/xschem_emergencysave_* dirs appeared during my T1 runs (F14 segfaults, mixed with other crews'). They are left in place.


## regression refuter (arrived last)

## refuted: True
## reasoning: Verdict: refuted on one narrow point. Everything else in the claim reproduced. HEAD is bc61cd05. Clones are at /var/tmp/xschem_fixes/s2cv2/{tree,base,tree_h}, where tree = HEAD + s2c_I/final.patch (md5 7f07f0e3) and base = HEAD + the main tree's issue-stamp diff (md5 7600660c, the same as issue_stamp_main.diff). Both built with rc 0. Run artefacts are in /var/tmp/xschem_fixes/s2cv2/runs/<label>/ and tools in /var/tmp/xschem_fixes/s2c_V2/tools/.

WHAT HOLDS (MEASURED unless tagged):
1. T1 in the main-tree shape is ZERO. With DISPLAY set to a private Xvfb, which is how the 09-17 baseline ran (DISPLAY inherited):
   - t1_tree_d: `T1-RUN-END cases=87 blocks=86 counted_failures=0`; t1_base_d: 85/84/0.
   - With a COPY of the real ~/.xschem, .gitconfig, .ngspice_history and the fork ngspice as the parent HOME: t1_rc_tree 87/86/0 against t1_rc_base 85/84/0.
   - Tree canaries were byte-identical with 0 inotify events. Every shared case has identical check counts; the only difference is 1476 at 37 vs 36, the new V4b row.
   - The four F14 suites pass with the same counts in tree and base: op_annot 485, optier 109, unused_attr 67, auto_specialize 85.
   - An XDG_* variant (all four set to canary dirs): 87/86/0, canary identical.
2. F14 is caused by DISPLAY being unset, not by a fresh clone (confirms D13.12). test_ase_optier_0963 run bare gives signal 11 with DISPLAY unset and ALL PASS (109) with DISPLAY=:197. With DISPLAY unset it crashes even with a copy of the real home. With DISPLAY unset every clone T1 is 87/86/8 against the base's 85/84/8, identical per case.
3. Trailer arithmetic: tcases 3 + hcases 72 + dcases 11 + xschemtest 1 = 87 Start and 87 Finish lines. The verdict has 86 block headers and 86 `Total num fail:` lines, and wc -l = 185 (2 + 86 + 86 + 8 counted + 3 NOGOLD). Measured on 5 runs.
4. The header survives hostile XSCHEM values. I tried 16: a space, `\nFATAL`, a trailing FAIL, GOLD?, RESULT?, a trailing \n, \r, a bare FATAL, `FAIL\nFATAL`, U+2028, NEL, VT, FF, TAB, 0x1C, `canonical=FAIL`, and an embedded `T1-RUN-END ...`. Each header stayed ONE line and scored 0 counted lines under grep, Python splitlines and Tcl gets.
5. Attach: a fixture Xvfb :195 -audit 4 with a seeded state dir gave `display arm: attached`. All 11 dcase xschem pids had DISPLAY=:195, and each appears twice in the server's own audit log. The canary, state dir included, was byte-identical, and the result was 87/86/8 identical per case. The shell attach path (run_suites.sh on fixture :196) was also confirmed through the audit log.
6. Auto-start (empty state dir, DEVDISPLAY_NUM=197): `started the dev display ... with the pre-switch HOME`. /proc/<pid>/environ shows HOME=<canary>, never the throwaway, for both the persistent Xvfb :197 and openbox. The canary gained only the state-dir files and .cache/openbox, which is the developer shape D13.2 describes.
7. Private fallback: Xvfb :100 or :101 was gone at the end of every run, with no lock and no process left.
8. Two concurrent T1s in one tree: 3 pairs (1 s, 0 s and 2 s stagger) were all 87/86/8, identical per case, canary identical, nothing left over.
9. The three suites are green in tree_h (76, 53 and 37 checks). Each of my 8 sabotages reddened its target rows and was md5-restored:
   - SV1 (t1_hdr_word does no replacement): H1d and H1e red.
   - SV2 (preswitch_env returns {}): A3c, B1d, H2 and L2b red.
   - SV3 (t1_home_kill_xvfb is a no-op): F1b and H1b red.
   - SS1 (no handoff call): W2, X1, X3, X5 and E1 red.
   - SS2 (XSCHEM_DEVDISPLAY_DIR not carried): F6 red.
   - SS3 (shell sweep ignores age): N6, G2 and G7 red.
   - SC1 (canonical= before home=): V4b red.
   - SC2 (no line buffering): V1c red.
10. test_ase_converge_1459 run bare: 70 checks with XSCHEM_TEST_REAL_HOME unset (plus a `skip: EE/fork` line naming the path), 76 with it set to a canary holding the fork.
11. The scratch.tcl notice:
   - It is present on stderr in bare runs.
   - It is absent from all 200 T1 case logs, which capture stderr through 2>@1.
   - It is absent from a teed run_suites capture of 341 lines.
   - All xschem --script processes under run_suites had a throwaway HOME (63 samples).
   - It never scores as counted; test_scratch_home_note is ALL PASS (20), rows C1–C4.
12. Coverage across all suites: run_suites.sh over every test_*.tcl, tree (405) against base (402), with the fork in both canaries. Every shared suite had the same verdict and the same RESULT text, check counts included, except 1476 (37 vs 36) and one tree-only failure: test_cmdmode_descend_0201 row MS9c. On rerun that suite passed 6/6 in both trees, so I count it as a flake. The tree canary stayed identical.

WHAT IS REFUTED: "concurrency (two T1s) still works / the new suites are green". Row H1b of test_home_isolation.tcl (the `check H1b-and-leaves-no-display...` expression) requires `![file exists /tmp/.X$pnum-lock]`. That is a check on a display NUMBER, not on identity. A concurrent run that starts its own private Xvfb on the number just freed turns H1b red.
- MEASURED: 1 red in 14 concurrent standalone pairs. In trial 3, run 1's H1 used :100 (pid 1247812, dead), run 2's H4 then took :100, and H1b failed with "lock left=1": `RESULT: 1 FAILED (75 passed)`.
- MEASURED: the precondition happens inside real T1 pairs. In the simultaneous pair, both runs' H sections began at 05:40:28.
- NOT observed at T1 level in 3 pairs, so T1-level is INFERRED.
- This is the W12b class: a shared namespace matched by pattern or number instead of identity. The fix is one line: compare the lock file's content with $ppid, as stop_pid already does.

Also: after `kill -9` of the driver, the private Xvfb and openbox survive (orphaned) until the next armed run at least 300 s later. That sweep did kill both and removed the lock and the throwaway (MEASURED). So "no leak after kill -9" is only eventually true.
## problems:
  * REFUTING, MEASURED: tests/headless/test_home_isolation.tcl row H1b checks `![file exists /tmp/.X$pnum-lock]` by display NUMBER. When another concurrent run starts a private Xvfb on the number just freed, H1b goes red. Standalone concurrent pairs: 1 red in 14 (trial 3, run 1: `FAIL: H1b-... Xvfb 1247812 running=0 ... lock left=1`; run 2's H4 had taken :100). In a real simultaneous T1 pair, both runs entered the H section in the same second (drv start=05:40:28 in both). 3 T1 pairs stayed green, so a T1-level red is INFERRED, not observed. Fix: compare the lock file's content with $ppid (identity), as stop_pid already does.
  * MEASURED: after kill -9 of the T1 driver during the display arm, the private Xvfb :100 (pid 1291611) and openbox (1291652) were reparented to init and kept /tmp/.X100-lock. They survived until the next armed run 305 s later, whose sweep killed both and removed the lock and the throwaway (`test home: swept 1 dead run(s)`). The leak is bounded only if someone runs again. A shell-side sweep kills only the Xvfb; openbox then exits with its server (measured).
  * MEASURED, confirms D13.12: the '8 counted failures from F14 fresh-clone segfaults' in every crew proof come from DISPLAY being unset. The same clones give counted_failures=0 with DISPLAY set to a private Xvfb (tree 87/86/0, base 85/84/0; also with a real-home copy as parent). optier crashes with DISPLAY unset even with a copy of the real home. Consequence: none of the crews' D11 T1 proofs (all DISPLAY-unset) ran the tails of those four suites under a throwaway. My DISPLAY-set runs did, with identical counts.
  * MINOR, MEASURED: a hostile XSCHEM containing `T1-RUN-END cases=87 ...` puts that text inside a killed run's header (binary=/x/T1-RUN-END_cases=87...). The in-tree reader verdict_finished anchors `^T1-RUN-END ` and is unaffected. Only an ad-hoc unanchored `grep T1-RUN-END` would take the killed run as finished.
  * MINOR, MEASURED: the auto-started persistent display (Xvfb :197 and openbox) correctly carries HOME=<pre-switch home>, but it also inherits harness variables: XSCHEM_TEST_REAL_HOME, XSCHEM_DEVDISPLAY_DIR, and GIT_CONFIG_COUNT/KEY_0/VALUE_0 (safe.directory=<this checkout>). Probably harmless, but these outlive the run inside a long-lived process.
  * MEASURED flake, not attributed to Item 2: in the full-corpus run_suites comparison, the tree alone failed test_cmdmode_descend_0201 row MS9c once. On rerun it passed 6/6 in tree and 6/6 in base.
  * DEVIATION: the clones, canaries and runs are in the lowercase sibling /var/tmp/xschem_fixes/s2cv2. s2c_V2 contains an uppercase V, which triggers D12's uppercase confound. Tools are in /var/tmp/xschem_fixes/s2c_V2/tools. Scratch left: s2cv2 1.9 GB.
  * Displays outside 195-199, all started by the harness under test, never as fixtures of mine: T1's private arm (:100/:101, hard-coded to scan from 100), test_home_isolation's built-in fixtures (:150/:151), and _sh's xvfb-run from :160. I pinned DEVDISPLAY_NUM to 196–198 and shimmed the drivers' xvfb-run to start at 197 or 199, so no run probed :99. The :99 orphan was already gone when I checked at 06:10, which matches D13.13; I never touched it.
  * About 69 /tmp/xschem_emergencysave_* dirs are newer than my start marker. They come from my DISPLAY-unset T1 runs and the concurrent verifier's, and I left them in place.
## real_home_check: Marker: /var/tmp/xschem_fixes/s2c_V2/.start_marker, touched at 05:02.
- `md5sum -c --quiet …/xschem_manifest_fixes.md5`: rc 0 at the start, at 05:37 and at the end (06:41).
- `find /home/analog/.xschem /home/analog/.claude/xschem_dev_display /home/analog/.claude/gui_test_gate -newer <marker>`: printed nothing, mid-stage and at the end.
- ~/.cache/openbox: nothing newer than the marker.
- The real state dir's files are unchanged since 2026-09-15 08:09.
- Newest /tmp/Xschem.log* is .4 from 09-17 23:35, so no interactive session was running.
- Every xschem or driver run used HOME = a canary or scratch dir under /var/tmp/xschem_fixes/s2cv2. Nothing ran with HOME=/home/analog, and XSCHEM_TEST_REAL_HOME was never set to it: the fork ngspice was COPIED into the canaries.
- Main tree: read only, plus `git diff` and `git clone`. Its 3 new status entries (DECISIONS.md D13 and receipts/S2c_refute_r1.md) are not mine.
- At the end: no process with a canary or /tmp/xschem-test-home.* HOME, no /tmp/xschem-test-home.*, and no /tmp/.X*-lock. No Xvfb or openbox of mine is running.
