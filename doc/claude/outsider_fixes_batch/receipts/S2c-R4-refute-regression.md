# S2c-R4 regression refuter (crew r4v2)

**Verdict: NOT REFUTED on regression.** No blocking finding. Round 4 (`r4.patch`, D20) keeps every
measured regression property of round 3:
* T1 is 87/86/0 in every main-tree shape I ran, and identical per case to base.
* No suite lost a check.
* Attach, auto-start and concurrency all work.
* No new row flaked under 4-way concurrency.
* No killed run leaked a display.
* `devdisplay.sh`'s real lifecycle is green.

What I did find are two coverage gaps in the new code and some pre-existing items. They are listed under
"Not blocking" below.

Tags: **M** = measured by me, **R** = read from source, **I** = inferred.

## Setup (M)

| clone | contents |
|---|---|
| `/var/tmp/xschem_fixes/r4v2/tree` (fix) | main HEAD `32b6a9cd` with `r3b/final_item2_only.patch` reversed and `r4b/final_item2_only.patch` applied (md5 `003df5ce…`) |
| `/var/tmp/xschem_fixes/r4v2/base` | main HEAD `32b6a9cd`, which already carries round 3 as `7a46275f`. `git apply --check -R r3b/final_item2_only.patch` gave rc 0 |

* **Deviation:** the brief said to build base as "HEAD + r3 patch". HEAD already contains round 3, so base is HEAD itself.
* The fix tree is identical, `.git` excluded, to HEAD + `r4.patch` (md5 `90ee1877…`). For all 13 touched files it is also md5-identical to `r4b/tree`.
* Both clones built with rc 0.

**Environment for every run:** `env -i`, with HOME set to a canary under `r4v2/canaries`. The canaries were either:
* `real`/`realdev`: a relocated copy of the real `~/.xschem` plus `.gitconfig`, `.ngspice_history`, the D11 sentinels and a **copied** fork ngspice;
* or `seeded` / `empty`.

Each run took a find+md5 snapshot before and after, an inotify record, and a scan for leftover processes (`tools/run.sh`).

**Display numbers:**
* Fixtures ran only on my numbers: :195 (T1's DISPLAY, with openbox), :196 and :197 (dev displays, then `AUDIT_DISPLAY` fixtures), and :198/:199.
* An `xvfb-run` shim forced 198/199 and waited for a free number; it made 522 calls and never reported NONE FREE.
* The code under test chose :100–:107 (T1's private arm) and 150–169 (the suites' fixtures).
* **:99 was never started, probed or stopped.**

## T1, main-tree shape, DISPLAY=:195 (M)

| run | display arm | trailer | canary |
|---|---|---|---|
| fix, attach (dev display :196 started by the fix's `devdisplay.sh start`, state dir in the canary) | attached; the sampler saw the display-case xschems on `DISPLAY=:196` | cases=87 blocks=86 counted_failures=0, 776 s, 87/87 Start/Finish, `wc -l` 177 | identical, 0 events; the state dir too |
| **base**, attach (:197), run concurrently with the row above | attached | 87/86/0, 760 s, `wc -l` 177 | identical |
| fix, **auto-start** (the user's real state shape: `xvfb.pid` and `wm.pid` naming dead pids, `DEVDISPLAY_NUM=196`) | started the dev display with the pre-switch HOME. The started Xvfb and openbox had HOME = the canary and 0 `XSCHEM_TEST_*`/`GIT_CONFIG_*`/`XSCHEM_DEVDISPLAY_DIR` variables; the cases ran on :196 | 87/86/0, 645 s | changed only in the D13.2 files: the 5 state files and `.cache/openbox` |
| fix, **stranger**, run **concurrently in the same tree** as the auto-start row | PRIVATE :100; the peer banner printed once | 87/86/0, 645 s | identical |
| fix, **checkout INSIDE the canary HOME** (`$C/dev/xschem-claude`, the user's real layout) | PRIVATE :100 | 87/86/0, 629 s | identical outside the checkout: 0 of 1.27 M inotify events fell outside `dev/xschem-claude` |

**Per case (M):**
* `percase.py`: all 86 blocks are identical, fix against base.
* `checks.py`: the RESULT lines match in 85 of 87 logs. The two differences are the expected new checks: `test_home_isolation` 116 against 111, and `_sh` 90 against 87.
* The auto-start, stranger and in-HOME runs are identical to the fix's attach run in all 87 RESULT lines.
* No flake appeared, so nothing needed the 3× rerun.

## Suites losing checks (M)

* **`run_suites.sh` over all 405 `test_*.tcl`, fix against base, run concurrently.** The fix ran on fixture :196 and base on :197, both with `GUI_GATE=0`, both on a relocated real-home canary:
  * 403 of 405 have the same verdict and RESULT text. The only differences are the +5 and +3 above.
  * The verdict counts are identical: 349 PASS, 17 NORESULT, 18 SKIP, 14 FAIL, 7 TIMEOUT in both. The FAIL and TIMEOUT sets are pre-existing and are the same suites in both.
  * Both canaries stayed identical.
* **The 12 standalone `.sh` suites** (the 7 `--arm` suites, `gui_gate_batch`/`revive`, `owed`, `wslg_health`, `test_home`), fix against base: the RESULT line and the ok and FAIL counts are identical for every one, and every canary stayed identical. The FAILs present are identical in base.
* **`test_devdisplay.sh`** with a FOREIGN number: fix ALL PASS (53), base ALL PASS (43). Every base check name is present in the fix. D17 was reworded into "server and WM … on the display it recorded".
* **`tools/migrate/test_ase_migrate.py`:** 151 in both. The fix left the canary identical; base changed it.
* **`lookshot.sh`** on an EMPTY canary: rc 0 and a PNG in both. The fix built winshot into `tests/headless/.winshot-cache`, and `git status` was clean.
* **`xarm.sh one test_crossview_paste.tcl`** on an EMPTY canary: PASS=28, rc 0, the canary stayed empty.

## Concurrency (M)

* **Race.** 4 T1 driver copies (one stand-in dcase each) started in the same instant, for 8 rounds: 32 runs.
  * 5 lost races were handled.
  * Every round got 4 distinct displays, and each case reached its own.
  * All 32 runs were 0 counted.
  * Nothing was left behind: no Xvfb, openbox or reaper by HOME or argv, and no throwaway.
* **`test_home_isolation`, 4-way × 3:** 12 of 12 ALL PASS (116), 0 skips. This covers the new H6d, H6e, H7b, L15 g–k, L19, G2 and G2b.
* **`test_home_isolation_sh`, 4-way × 2 with one display number each:** 8 of 8 ALL PASS (90).
* **`test_devdisplay.sh`, 2-way × 3 with its own numbers:** 6 of 6 ALL PASS (49, D11 skipped). At 3-way the new rows (D17c, D17d, D19–D22) were green 6 of 6.
* **1476, 4-way:** 4 of 4 ALL PASS (37).
* **Canaries** stayed identical in all of the above.

## Killed runs (M)

**T1 path** (driver copy; the stand-in Xvfb execs the real one):

| trials | result |
|---|---|
| timed kill -9 at 0–2000 ms after the Xvfb starts, 21 trials | 0 of 21 left anything; gone after 52–4968 ms |
| self-kill (the stand-in SIGKILLs T1 as its first act), 15 trials | 0 of 15; gone after about 53 ms |
| pinned to one core shared with 2 CPU hogs, 8 self and 5 timed | 0 of 13; gone after at most 5136 ms. In 5 of the 8 self-kills `.xvfb.pid` was never written, and the server was still reaped through its tag |
| 6 trials that left the reapers alone | every reaper exited by itself within 10 s |
| **total** | **0 of 55 leaked; the worst was 5.1 s**, and no lock was left |

**Shell path** (`run_suites` on the private arm): 0 of 8 leaked, gone after at most 1.3 s.

## `devdisplay.sh`, real lifecycle on a canary state dir, :197 (M; `tools/ddlife.sh`)

**Fix: 39 of 39 checks passed.** They covered:
* start, and a second start that is idempotent (same pid, one WM);
* the started WM passes `_wm_is` and `_wm_alive`;
* status alive; status naming the WM by xprop;
* exec, which routes DISPLAY and sets `GUI_GATE=0`;
* a GUI xschem through exec;
* `view` and `view --stop`;
* stop with decoys recorded, which kills none of them and keeps the lock;
* stop, which stops its own server, WM and lock;
* stop **TERMs its own WM while the server is SIGSTOPped**, so `_wm_is` identifies a real WM;
* stale locks naming a dead pid and a live non-X pid;
* restart, after which the old WM is gone and exactly 1 WM serves;
* a foreign server: start rc 4, status foreign, exec rc 6, stop spares it;
* the user's real state shape (both pids dead): stale, then start, then stop;
* the old format;
* WM-less.

**Base: 37 of 39.** The two misses are expected:
* L2b: `_wm_is` does not exist in base.
* L7d: base's stop first waits out a 5 s `xdpyinfo` against the frozen server, so its WM kill lands after my 6 s window. That is my test's timing, not a defect.

## Sabotages on the round-4 code (M; 13, applied to a copy `sab` and restored after each)

**Red, 8 of them:**

| id | sabotage | red row |
|---|---|---|
| SB | `_wm_is` without HOME | D22 (1011) |
| SC | `_wm_is` without DISPLAY | D22 (1101) |
| SE | sweep without the display check | D17c |
| SG | sweep matches the WM by argv word | D17 |
| SJ | reaper phase 1 cut to 0.1 s | H6e |
| SL | Tcl escape walk without `.claude` | L15 |
| SL2 | shell escape walk without `.claude` | L15 |
| SN | winshot's temp dir not removed | W10 |

**Green, 5 of them:** SA, SF, SH, SI and SK. The next section says what each means.

## Not blocking

1. **GAP, new code (M).** No row covers the `cmd_stop` kill site with a **live** server.
   * **Sabotage SA** reverts `_kill_wm "$xp"` to the old `_kill_pidfile wm.pid "$(_wm_name)"`, which matches by name only. `test_devdisplay.sh` stays ALL PASS (49 checks).
   * **Why nothing notices:** D22 tests only the predicate, and D21 tests only the dead-server short-circuit.
   * **Probe** (`probe_sa/probe.sh`): a live recorded Xvfb, with `wm.pid` naming an openbox either on another DISPLAY or with another HOME.
     * The fix spares that openbox in both cases.
     * Under SA, and in base, `stop` kills it.
   * **Suggested row:** D22's two decoys, used as `wm.pid` under a live server, followed by `stop`.
2. **GAP, safe direction (M).** Sabotage SF makes the sweep ignore `.reaper_display` and read only `display`. It stays green.
   * No row reclaims a dir that holds only `.reaper_display`: a run killed inside `start`.
   * The failure direction is safe: a leftover survives.
3. **Equivalent, not gaps (M).** Three sabotages stayed green because they change nothing observable:
   * SH (the reaper skips the `env` stage): the stage lasts microseconds and the next rescan sees the Xvfb.
   * SI (the WM is untagged): openbox dies with its server.
   * SK (teardown kills only the first reaper): the others exit when their server goes.
4. **G2 scans the working tree, untracked files included (R+M).**
   * **Effect:** T1's verdict depends on scratch scripts that sit in a checkout.
   * **Today it is clean:** the round-4 scanner run read-only over the main tree finds 3 offenders, all in the two files `r4.patch` arms, and 0 after the patch.
5. **H6d reports "wrapped" as a failure (R)** when the pid counter wraps between the two forks. The chance is about 1e-5 per run.
6. **PRE-EXISTING, identical in base: the shell private arm's display-number choice races (M).**
   * **Shared pool:** with 4-way `_sh` sharing my 2-number `xvfb-run` pool, the older X rows (X1–X3, X5, X7, X7b, X8, X9) went red in 3 of 8 fix runs and 4 of 8 base runs. `test_devdisplay` D6 went red in 2 of 6 at 3-way.
   * **Own numbers:** with a number per run, all of them passed 8 of 8 and 6 of 6.
   * **Cause:** my shim's check-then-exec is a race: two shims chose :199 in the same millisecond. `xvfb-run -a` itself has the same race (R).
   * **Scope:** none of these rows are new in round 4, and `xvfb_arm.sh` is not in the patch.
7. **Pre-existing hygiene.** `test_gui_gate_revive.sh` leaves a `sleep 300` decoy with HOME = the parent home, in both trees. I killed both by pid.

## Real home (M)

* **Manifest:** `md5sum -c --quiet …/xschem_manifest_fixes.md5` gave rc 0 at the start and at the end.
* **Find:** `find ~/.xschem ~/.claude/{xschem_dev_display,gui_test_gate,xschem_owed} ~/.cache -newer /var/tmp/xschem_fixes/r4v2/.start_marker` printed nothing.
* **The real state dir** is unchanged: dated 2026-09-15 08:09.
* **No interactive xschem:** the newest log is still `/tmp/Xschem.log.4`.
* **HOME:** always a canary or scratch dir under r4v2. `XSCHEM_OWED_DIR` pointed into the canary.
* **Main tree:** only read (including a read-only G2 scan), plus this file. Nothing was done in `~/dev/xschem-op-wcard`.
* **Kills:** only by pid, after a HOME check in environ: my fixtures, my CPU hogs and the two decoy sleeps. No `pkill`.
* **Nothing left:** no processes of mine, no `/tmp/.X19[5-9]-lock`, no `/tmp/xschem-test-home.*`.
* **Emergency-save dirs:** the `/tmp/xschem_emergencysave_*` dirs dated inside my window are not named by any output of mine (several crews were running), so I left them.
* **Scratch for the driver to delete:** `/var/tmp/xschem_fixes/r4v2` (3.0 GB).
