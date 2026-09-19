# S2c-R3-build: D17, round 3 of Item 2 (crew R3B)

**Status: DONE.**
Every D17 item (1, 3–9) is implemented, and each guard was measured red first:
* on the r2base code with the new tests, or
* with a named sabotage on the final code, or
* with the round-2 refuters' recipe on both trees.

Item 2, the fresh-canary proof, was run for the three newly armed launchers.

The launcher guard (G2) found no unarmed launcher beyond the three that round 2 named. It classifies all 43 scripts under `tests/` that start xschem.

Tags: **M** = measured (I ran it; the output is quoted), **R** = read from source, **I** = inferred.

## Deliverables

| file | md5 |
|---|---|
| `/var/tmp/xschem_fixes/r3b/r3.patch`: incremental on `r2base` (`ed1a727f` = `4da72c24` + istamp_s1fix + r2i final). 12 files, +1167/−149. No new files. | `e9daccad05796cbb2107c48a48f12aca` |
| `/var/tmp/xschem_fixes/r3b/final_item2_only.patch`: cumulative from `4da72c24` (r2base~1). The two issue-stamp files are excluded. 29 files, +6862/−92. | `b6a4367b7728701395b66f70a6e00cb1` |

* `git -C /home/analog/dev/xschem-claude apply --check …/final_item2_only.patch` gave **rc 0**. The check is read-only. The main tree's HEAD is `9fbc6fd9`, which moved from `4da72c24` through docs-only commits. (M)
* The four files new to the cumulative diff are `devdisplay.sh`, `lookshot.sh`, `netlist_diff/netlist_diff.sh` and `wireedit/run_wireedit.sh`.

## What changed, by D17 item

### 1. The launcher guard: row **G2** in `test_home_isolation.tcl`

**Scope.** It walks `tests/` (skipping `results*`, `gold` and dot-dirs) over `.sh`, `.bash`, `.py`, `.tcl` and extensionless files with a shebang.

**What "starts xschem" means.** A non-comment line names the binary in one of these forms:
* `src/xschem`;
* `src xschem` (a Tcl `file join`);
* `$XSCHEM` or `${XSCHEM`;
* `env(XSCHEM)`;
* `xschem_cmd`;
* in a non-Tcl file, a bare `xschem -…` in command position.

**The four classes.** Each such line must fall into one of them:
* **armed:** an arm comes earlier in the file. That is `test_home_arm`, a `test_home.sh --run` or `xvfb_arm.sh --arm` re-exec guard, `source …test_utility.tcl`, or `t1_arm_home`;
* **inside:** a `.tcl` suite with no tclsh shebang that runs inside xschem, meaning it sources `scratch.tcl` or calls the `xschem` command. This is D9's case;
* **allowed:** the line is on `G2ALLOW` with a one-line reason;
* **delegation:** the line only names armed drivers (`gated_xschem.sh`, `run_suites.sh`, `full_audit.sh`) or arming re-execs. It needs nothing.

**What the row checks.** It fails on any offender. It also fails if a known launcher is not seen as armed (lookshot, netlist_diff, run_wireedit, run_suites, full_audit, gated_xschem, run_regression, netlisting). It prints every launcher and its class.

**The final classification (M, run hi4):**
* **armed, 22:** `create_save.tcl`, `netlisting.tcl`, `open_close.tcl`, `run_regression.tcl`, `test_utility.tcl`, `full_audit.sh`, `gated_xschem.sh`, `lookshot.sh`, `run.sh`, `run_nogui.sh`, `run_suites.sh`, the 7 `--arm` suites (`test_action_log`, `test_action_replay`, `test_file_menu_log`, `test_flylines`, `test_readonly_action_dispatch`, `test_readonly_guard`, `test_recent_launchlog`), `test_devdisplay.sh`, `test_home_isolation_sh.tcl`, `netlist_diff.sh` and `wireedit/run_wireedit.sh`.
* **allowlisted, 3:**
  * `test_owed.sh`: its line is a `[ -x …src/xschem ]` precondition; its only start is O13's `owed.sh drain`, which goes through `run_suites.sh`.
  * `test_pdk_launcher.tcl`: it builds the launcher's command line as a list and never runs it.
  * `fuzz_sweep.tcl`: it writes a usage comment into a generated file, and the sweep itself runs inside xschem.
* **inside xschem:** 18 suites.
* **UNARMED:** none.

**Armed in this round**, which were the only unarmed launchers the guard found:
* **`lookshot.sh`** sources `test_home.sh` and runs `test_home_arm`. Its `winshot.sh` build cache follows HOME into the throwaway.
* **`netlist_diff.sh`** does the same. Its own EXIT trap now also calls `_th_cleanup`.
* **`wireedit/run_wireedit.sh`** is POSIX, so it uses the `test_home.sh --run` re-exec guard (the `run.sh` shape).

**`test_home_isolation_sh` W3** gained the three launchers as named wiring checks.

### 3. Relative TMPDIR
* **Shell:** `_th_abs_tmpdir` runs at the top of `test_home_arm` and **exports** TMPDIR absolute.
  * The fresh arm refuses when a relative TMPDIR names no directory.
  * `_th_takeover` and the fresh arm share `_th_root`.
* **Tcl:** the same export, for symmetry (a deviation; see Deviations).

### 4. Nesting requires HOME directly under the temp root
* Both languages compare physically resolved paths.
* **Shell:** `_th_parent_phys` against `_th_phys` of the root.
* **Tcl:** `t1_home_under_root`.
* A throwaway-shaped HOME outside the root prints `!! test home: note: … not directly under the temp root …; arming a fresh one` and arms fresh.

### 5. A custom dir whose `.xschem` resolves into the real HOME is refused
Both languages apply the rule: shell `_th_custom_escapes`, Tcl `t1_home_custom_escapes`.

**What is checked:** `.xschem` itself **and each entry directly in it**, resolved with `readlink -m`, so a dangling link counts.

**When it is allowed:** only where the custom dir is itself inside the real home and the entry stays inside the custom dir. That is L11b's announced case.

### 6. Kill only by identity; remove a lock only by content

**`devdisplay.sh`:**
* `_pid_is` now identifies a process by **argv[0]**, not "the word anywhere in the command line".
* `_kill_pidfile <file> <prog> [<dpy>]` kills only if `_pid_is` passes: `Xvfb :N`, the recorded WM, `x11vnc` with `:N`. The pidfile is always removed.
* `stop` removes `/tmp/.X<N>-lock` only if it names the Xvfb that passed identity and is now gone (`_rm_lock_if_names`).
* `_ours` also requires that an existing lock name the recorded pid. This is the R2I open-problem-3 "defect A" shape.
* `start` removes a stale lock only if the pid it names is not a running X server.

**`test_devdisplay.sh`:**
* `_cleanup` no longer runs `pkill -f "Xvfb [:]$FOREIGN"`. FOREIGN is a tracked pid.
* Its locks go only if they name a server of this run's (`OURX`) that is gone.
* The display numbers come from `DEVDISPLAY_TEST_NUMS` / `DEVDISPLAY_TEST_FOREIGN_NUMS`, whose defaults are unchanged, and `:99` is never taken.

**`spawn_reaper.sh` `reaper_sweep_orphan_runs`:** a recorded pid is killed only if argv[0] matches its pidfile's program (`xvfb.pid`→Xvfb, `vnc.pid`→x11vnc, `wm.pid`→the dir's `wm`, or `file=prog`). This is the "nothing killed on a recorded pid alone" part of D17.6. The test_devdisplay orphan sweep uses it.

### 7. No reaper window

**Shell (`xvfb_arm.sh`):**
* `_xvfb_start_reaper` runs in the **pre-exec process, before `exec xvfb-run`**. xvfb-run keeps that pid and start time.
* The process exports `XSCHEM_TEST_XVFB_TAG=<pid>.<starttime>.<boot>`, and the whole session inherits it.
* The detached reaper polls the owner every 0.5 s. Once the owner is gone, it kills every process whose argv[0] is Xvfb or the WM **and** whose environ carries that exact tag. The scan repeats until it comes back empty twice.
* It then removes the lock by content.
* The launcher's old in-session reaper is removed.
* The server (and the WM) are **recorded in the owner's throwaway**, as `.xvfb.pid`, `.xvfb/display`, `.xvfb/wm.pid` and `.xvfb/wm`. This happens only when `.owner` names the xvfb-run pid or the launcher, so the sweep can kill them by identity.

**Tcl (`run_regression.tcl`):**
* `t1_private_reaper` is started immediately after the Xvfb `exec`, with the WM name. It waits (bounded) for the pid to become Xvfb.
* After the owner dies, it also stops any process named Xvfb or the WM with `HOME=<run dir>`.

### 8. `-n <base> -a` in xvfb_arm's private path, never `:99`
* `AUDIT_XVFB_BASE` defaults to **200**. A value below 100, or one that is not a number, is corrected with a notice.
* `-n` is passed **before** `-a`, because xvfb-run applies options in order (R: `/usr/bin/xvfb-run` `find_free_servernum`).
* `test_devdisplay.sh` reaches this path through `xvfb_arm --arm` (its D6), and gained a row for it.

### 9. Rows
* **H8.** An `Xvfb` on PATH that exits at once must produce a counted `HARNESS … FAIL`, `Total num fail: 1`, `counted_failures=1` and no NODISPLAY.
* **Fixtures.** `free_fixture_num` now draws from 150–169, and H2's and H3's numbers are released as soon as their rows end (`release_fixture_num`).
* **The drain banner.** The shell's **nested arm is now silent**, as Tcl's always was (L18). `owed.sh drain` prints the banner once (W8b).

## Defects my own measurements found, and fixed (each measured red, then green)

**A. The owner's cleanup killed the recorded server under a live xvfb-run.**
* Once the shell path recorded its server, `_th_cleanup` killed it before xvfb-run did.
* xvfb-run's `clean_up` runs `kill $XVFBPID` under `set -e`, so the run's exit status became **1**.
* Measured red on hs2: X3, X5, X8 and W5 all got rc 1 instead of 5/0/0/4.
* Fix: `_th_kill_recorded_display … defer`. It leaves a server whose parent is a live xvfb-run to xvfb-run. The sweep never defers.

**B. `_ours`' lock check made H7's stand-in look like a server that never answers.**
* Measured: "Xvfb :100 started but did not answer within 10 s" in `tools/h7repro.tcl`.
* Fix: T1's up-check now reads the lock on every poll, and a lock naming another pid is a lost race right away.
* H7's stand-in loser now looks like a real one: argv[0] `Xvfb`, with the display word.
* Under the SH7 sabotage, H7 is red.

**C. Reapers of abandoned attempts lingered.**
* In the first 4-way × 5 measurement, **2 of 20** runs were red on H1b, with `its reaper still running=<pid>`. That was the reaper of a lost-race attempt, waiting out its 5 s poll.
* Fix: `t1_private_reaper` returns its pid, and `t1_private_reaper_stop` kills it (by identity) whenever an attempt is abandoned.
* The rerun was 0 of 20.

**D. Test tooling:** `date` on this box is uutils 0.8.0, which ignores `%3N`, so it printed nanoseconds and a wait never ended. The stand-ins use `date +%s%N | cut -c1-13`, and every such wait now has a deadline. (M)

## Measured on the final code (clone `/var/tmp/xschem_fixes/r3b/tree`)

**Environment.** Every run used `env -i` with:
* HOME = a seeded D11 canary (plus `untitled~.sch` and `Documents/`), snapshotted with `find -printf` plus an md5 of every file before and after;
* DISPLAY unset unless stated;
* `DEVDISPLAY_NUM=167`, `AUDIT_XVFB_BASE=160`, `XSCHEM_TEST_XVFB_BASE=160`;
* `XSCHEM_OWED_DIR` = a scratch path inside the canary.

| suite | result | canary |
|---|---|---|
| `test_home_isolation` | **ALL PASS (111 checks)**, up from 104 (+G2, H6c, H8, L15–L18) | identical |
| `test_home_isolation_sh` | **ALL PASS (87)**, up from 82 (+X9, X10, X11, W8b, B2; W3 and N10 changed) | identical |
| `test_regression_concurrency_1476` | **ALL PASS (37)** | identical |
| `test_devdisplay.sh` (numbers 166/164; D6 private `:160`) | **ALL PASS (43)**, up from 39 (+D6 "never :99", D17b, D18 ×2) | identical |
| `test_scratch_home_note` | **ALL PASS (21)** | identical |
| **T1**, `cd tests && tclsh run_regression.tcl`, DISPLAY = **my private Xvfb `:168`** | `T1-RUN-END pid=961981 cases=87 blocks=86 counted_failures=0 elapsed=477s`; 87 Start / 87 Finish; `wc -l` 177; header `home=throwaway binary=…/tree/src/xschem`; display arm `PRIVATE Xvfb :100` | identical |
| **4-way concurrent `test_home_isolation`, 5 rounds = 20 runs** | **20/20 ALL PASS (111), 0 skips, 0 fails** | all 20 identical |
| **`full_audit.sh`, run from cwd = the canary** | `SUMMARY: 392 pass 11 fail 0 crash/timeout 2 skip (total 405)`; private Xvfb `from :160 up`. The 11 fails are round 2's pre-existing list exactly: altf5_ciw, ase_dialogs, cadence_drag, cosim_golden_e2e, lib_manager_gui, lib_sweep, results_dialog, rotate_stretch_short_0104, selflog_output, wave_sigbrowser_0312, wave_sigbrowser_keys. The skips are expose_repaint and window_report. | identical; no process left |

**Fresh (EMPTY) canary, D17.2 (M; `tools/fresh_launchers.sh`, fixture `:162`):**

| launcher | final | r2base |
|---|---|---|
| `lookshot.sh` (png written, rc 0) | canary stays **empty** | creates `.xschem/xschemrc`, `.cache/xschem-winshot/{build.log,winshot}` |
| `netlist_diff.sh` (BYTE-IDENTICAL) | stays **empty** | creates `.xschem/xschemrc` |
| `run_wireedit.sh` (WIREEDIT: ALL PASS) | stays **empty** | creates `.xschem/xschemrc` |

**Kill recipe, D17.7 (M).** kill -9 at a random 50–150 ms after Xvfb starts (a PATH stand-in records the start and then execs the real server). 20 trials per path; "left" means the run's Xvfb or WM is still alive about 10 s later.

| path | final | r2base |
|---|---|---|
| shell: `run_suites.sh`, which by then is xvfb-run | **0 of 20** | **12 of 20**: Xvfb and openbox left, every one killed before about 95 ms |
| T1: a driver copy | **0 of 20** | **14 of 20**: Xvfb left |

## Red first (M)

**r2base code with the new tests.** Tree `baset` = `base` plus the three new test files. `xvfb-run` was shimmed to `-n 161`, so nothing could take `:99`.
* `test_home_isolation`: **6 FAILED**.
  * G2 names `lookshot.sh:39,45`, `netlist_diff.sh` and `run_wireedit.sh`.
  * H6c: the Xvfb was killed 61 ms after starting and outlived the run.
  * L15, L16, L17: both helpers were wrong, or Tcl was: `TMPDIR=reltmp` was exported relative.
  * L18: the shell printed 1 banner.
* `test_home_isolation_sh`: **7 FAILED**.
  * W3.
  * N10: it was nested.
  * X11: no record.
  * X9: `/tmp/.X161-lock` was left. I removed it by content afterwards.
  * X10: `-a -s …` with no `-n`.
  * W8b: 2 banners.
  * B2: `NORESULT`-shaped rc 1, with the throwaway left in the cwd.
* `test_devdisplay.sh`: **3 FAILED**. D17b killed the recycled pid. D18: all three sleep decoys were killed and the lock was removed.

**Sabotages on the final code** (clone `sab`; the three ran together because they are distinct rows; files restored and checked by md5):
* SG2 adds an unarmed `tests/headless/unarmed_probe.sh`. **G2 is red: `UNARMED: headless/unarmed_probe.sh:5`**.
* SV3 turns the HARNESS FAIL into NODISPLAY. **H8 is red** (`counted_failures=0`, NODISPLAY present).
* SH7 removes the arm's lock identity. **H7 is red.**
* Nothing else was red (108 of 111 passed).

**The `test_devdisplay` cleanup decoy recipe** (`tools/dd_cleanup_decoy.sh`). After D13, a lock on `:166` naming a live decoy was planted, and a decoy whose argv reads `Xvfb :164` got a lock of its own.
* **Final:** both decoys and both locks survive.
* **The same suite with the round-2 `_cleanup`:** the `Xvfb :164` decoy was killed (by `pkill -f`) and both locks were removed.

**Fixture scheme:** the r2base suite run 4-way skipped H3 in **2 of 4** runs ("no free display number"). The final code skipped 0 of 20.

## Deviations
1. **`devdisplay.sh _pid_is` identifies by argv[0]**, and `_ours` requires the lock to name the pid. This goes beyond "kill only by identity". It is the recorded R2I open problem 3 ("defect A shape"), fixed because an identity check that accepts `sleep … Xvfb :N` is not identity. It forced defect B's fix: the up-check reads the lock, and H7's stand-in changed. (M)
2. **`spawn_reaper.sh reaper_sweep_orphan_runs`** now requires argv[0] identity. This is D17.6's "nothing is killed on a recorded pid alone", applied to the one remaining recorded-pid kill in test_devdisplay's path. As a result, D17's decoy must be named Xvfb, and D17b is new.
3. **devdisplay `start`'s stale-lock removal is by content** (the named pid is not a running X server). D17.6 names only stop/`_ours`.
4. **Tcl also exports an absolute TMPDIR** (D17.3 names only the shell). Without it, D17.4 would make a Tcl child in another cwd fail its nesting test and arm a second throwaway (I). Row L17 locks both.
5. **The drain banner is fixed by making the shell's nested arm silent**, as Tcl's is, rather than by quietening the drain. It removes every double banner, not only the drain's. It changes the round-1 "left different on purpose" item. Locked by L18 and W8b.
6. **D17.5 checks the entries directly inside `.xschem` too** (for example a symlinked `simulations/`), not only `.xschem`. Row L15 case b.
7. **The shell reaper finds its targets by an inherited tag** (`XSCHEM_TEST_XVFB_TAG`), not by a recorded pid, because the pid does not exist yet at exec time. It passes HOME as an informational argument so that Z2 still sees whose it is. **The record** is written only into a throwaway this xvfb-run's own run owns. **Defect A's `defer`** is a new cleanup mode.
8. **`AUDIT_XVFB_BASE` defaults to 200, not 100**, to stay clear of T1's own private arm (:100–:199). D17.8 only requires 100 or more.
9. **`test_devdisplay.sh` gained `DEVDISPLAY_TEST_NUMS` / `DEVDISPLAY_TEST_FOREIGN_NUMS`**, so that my runs stayed on my numbers and the decoy recipe was possible. The defaults are unchanged.
10. **G2 allowlist:** 3 entries, each with a reason. Text-based detection classifies `test_home_isolation_sh.tcl` as "armed", because its fixtures spell `test_home_arm` before its first launch token. That is harmless (it also runs inside xschem).
11. **Display numbers.**
    * Code under test chose numbers outside mine: T1's private arm `:100`–`:103` (hard-coded), the H-rows' driver copies, and T1 itself.
    * Every fixture and shim of mine was in 150–169: `:160`–`:169` via `AUDIT_XVFB_BASE`, `XSCHEM_TEST_XVFB_BASE` and my `xvfb-run` shims; `:162` lookshot; `:164`/`:166` test_devdisplay; `:168` T1's DISPLAY; `:150`–`:169` fixtures.
    * `:99` was never started, probed or stopped. No run of r2base's `xvfb_arm` went unshimmed; X10 used a stand-in that starts nothing.
12. **The 4-way × 5 run** was done twice. The first was before defect C was fixed (0 skips, 2 H1b fails); the second on the final code. `run_regression.tcl` was edited during the first, and that edit touched only the reaper.

## Open problems
1. **Detection is textual.** G2 cannot see a launcher spelled another way: `$(command -v xschem)`, a binary path assembled from pieces, or a `.tcl` driver that neither calls `xschem` nor carries a tclsh shebang and is still run by tclsh. The row's comment says so.
2. **`winshot.sh` run standalone** still builds into `$HOME/.cache/xschem-winshot`. It starts no xschem, so G2 does not cover it. Under lookshot it now lands in the throwaway. (R)
3. **A SIGKILLed xvfb-run leaves its own auth dir** `$TMPDIR/xvfb-run.XXXXXX`. This predates the batch and is in TMPDIR, not HOME: 20 of them from my k9 trials, in my scratch. (M)
4. **T1's private arm is still hard-coded to start at `:100`.** It has no knob.
5. **`devdisplay.sh start` still has defect D's probe-then-openbox reset shape** (R2I open problem 3, first half). It is not changed.
6. **The Tcl `!! test home: note:` line** for a throwaway-shaped HOME outside the root goes to stdout, like its other `!!` notes. It matches no counted shape.
7. **Stage F still owes** the CLAUDE.md done-claim scoping and the D12 issue files, as before.
8. **Scratch for the driver to delete:** `/var/tmp/xschem_fixes/r3b`, which holds the tree, base, baset, sab, canaries, runs, k9, conc and fresh.

## Real home (M)
* **Marker:** `/var/tmp/xschem_fixes/r3b/.start_marker`, 13:05:29.
* **Manifest:** `md5sum -c --quiet …/xschem_manifest_fixes.md5` gave **rc 0** at the start, at mid-stage (13:57) and at the end.
* **Find:** `find ~/.xschem ~/.claude/xschem_dev_display ~/.claude/gui_test_gate ~/.claude/xschem_owed ~/.cache -newer <marker>` printed **nothing**, mid-stage and at the end.
* **No interactive xschem:** the newest `/tmp/Xschem.log*` is `.4`, from 09-17 23:35.
* **HOME and ledger:** every run's HOME was a canary or scratch dir under `/var/tmp/xschem_fixes/r3b`, and `XSCHEM_TEST_REAL_HOME` was never `/home/analog`. `XSCHEM_OWED_DIR` always pointed into a canary; W8/W8b and O-rows used the suite's scratch homes.
* **Displays:** `:99` was never touched. My fixture Xvfbs (`:162`, `:168`) were stopped by pid after an identity check. There are no `/tmp/.X*-lock` of mine at the end.
* **Emergency-save dirs:** one `/tmp/xschem_emergencysave_*` was named by my output (hi1, a suite I TERMed), and it is removed. Twenty others newer than the marker fall inside my k9/conc window. None was named by any output, so they were left.
* **Other crews:** processes of another crew (`s1fix6`, HOME under `/var/tmp/xschem_fixes/s1fix6`) were seen running `test_issue_stamp` in the main tree. They are not mine, and I did not touch them.
* **Main tree:** only read, cloned, `apply --check`ed, and this receipt written. Its `git status` shows other crews' issue-stamp edits, not mine. `~/dev/xschem-op-wcard` was not touched.
