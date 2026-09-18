# S2c-R2-I: integrate round 2 and re-prove Item 2 end to end (crew R2I)

**Status: DONE.** The integration itself (merge, the one-contract check, new L rows, and three
defects the proof found) is in **`S2c-R2-R2I.md`**. This receipt is the proof. Every D11/D13 shape
was run with a freshly seeded canary as the parent HOME:
* **Canary byte-identical in every shape except shape 9.** Shape 9 changed it only by D13.2's scoped
  exception: the state files and `.cache/openbox`.
* **0 inotify events** in every such shape.
* **No process left, no throwaway left.** The one exception is a killed run's home, which the next
  arm's sweep then collected, as designed.
* **Every red-first shape changed its canary** on the opt-out or on a HEAD+istamp baseline.
* **T1 is 87/86/0 on the final code.** Solo, and in a concurrent pair.

Tags: **M** measured (ran it; output quoted), **R** read from source, **I** inferred.

## Deliverables

| file | md5 |
|---|---|
| `/var/tmp/xschem_fixes/r2i/final_item2_only.patch`: the full Item-2 diff against `616110a6`, without the two issue-stamp files. 25 files, +5806/−54. | `ce1e512325a91e3f058f00abc1a259d1` |
| `/var/tmp/xschem_fixes/r2i/r2.patch`: incremental on `r1base`. | `d93723d36919616a90f96e5d230624a4` |

* `git -C /home/analog/dev/xschem-claude apply --check …/final_item2_only.patch` gave **rc 0**
  (read-only; M).
* The main HEAD moved **`733e03ad` → `616110a6` → `caa110ba` → `52453f1e`** during the stage (D14–D16).
  None of those commits touches the 25 files: they change `DECISIONS.md`, `LEDGER.md`, a receipt and the
  issue-stamp files. The patch is the diff against `616110a6`, the clone's original HEAD.
  **`apply --check` was re-run at `52453f1e`: rc 0.**

## Setup (M)

**Trees.** All proof trees are lowercase `--no-hardlinks` clones of the integration tree, each built
with rc 0:
* `ptree`, `ptree2`, `ptree3`, `ptree4`, `ptree5`;
* `base` = `616110a6` + `istamp_s1fix.patch` only (the HEAD+istamp baseline).

**The code under test moved during the stage**, because the proof found defects A, B and D:
* `r2i_1`: the integration;
* `r2i_2`: + A;
* `r2i_3`: + B;
* `r2i_4`: + D, **final**.

**The shapes that depend on those deltas were re-run on `r2i_4`:**
* T1 solo;
* the concurrent pair;
* full_audit;
* the suites.

The other shapes ran on `r2i_1`. None of `r2i_2`…`r2i_4` touches arming, HOME or any driver other
than T1's private-display start (R: `git diff --stat r2i_1 r2i_4`: `run_regression.tcl`,
`test_home_isolation.tcl`, `test_scratch_home_note.tcl` only).

**The canary** (`r2i/tools/seed.sh`), every mtime `@1789000000`:
* D11's set:
  * a sentinel `.xschem/.clipboard.sch`;
  * `simulations/clean.spice` and `short.spice`;
  * a 100-entry `geometry`;
  * `recent_files` and `ase_simulators`;
  * `.spiceinit`, `.ngspice_history` and `.gitconfig`;
* **plus** a tester's `untitled~.sch` at the root;
* **plus** a sentinel owed ledger `.claude/xschem_owed/{rule/9999,suite/…}`;
* `.Xauthority` and `Documents/`.

**Each run** (`r2i/tools/run.sh`):
* `env -i`, `HOME=<canary>`, `DISPLAY` unset unless stated;
* `DEVDISPLAY_NUM=188`;
* `XSCHEM_OWED_DIR=<canary>/.claude/xschem_owed`, so any owed write would land in the canary;
* `xvfb-run` shimmed to `-n 181`…`185`;
* `XSCHEM_TEST_XVFB_BASE=180` wherever `test_home_isolation_sh` runs;
* snapshots: `find -printf '%p %y %s %T@ %m'` plus an md5 of every regular file, before and after,
  with `iwatch.py` (reused from `s2a_redirect/tools`) over the whole canary;
* leftovers: any process whose `HOME` is the canary or a throwaway the run announced, reapers
  naming them, throwaways, locks.

**T1 runs** add `dsample.py`, a 20 ms pid-level sampler of every xschem the run started, with its
`DISPLAY`. Artefacts are in `/var/tmp/xschem_fixes/r2i/runs/<label>/`.

## The shapes

### 1. T1 (M)

| run | code | DISPLAY | trailer | canary | events | left |
|---|---|---|---|---|---|---|
| **`t1_final4`** | **r2i_4** | my `:189` | **`cases=87 blocks=86 counted_failures=0`**, 656 s | identical | 0 | 0 procs, own throwaway gone |
| `t1_final` | r2i_3 | `:189` | 87/86/**0**, 543 s | identical | 0 | 0 |
| `t1_disp2` | r2i_1 | `:189` | 87/86/**0**, 483 s | identical | 0 | 0 |
| `t1_disp` | r2i_1 | `:189` | 87/86/**1**: `open_close` one job **`exit 141`** (SIGPIPE, issue **0448**) | identical | 0 | 0 |
| **`t1_nodisp`** | r2i_1 | unset | 87/86/**8** | identical | 0 | 0 |
| `t1_base_nodisp` | base | unset | 85/84/**8** | **CHANGED** (2543 events) | | **Xvfb `:188` + openbox left, HOME=canary (F36)**. I stopped them with `devdisplay.sh stop` against the base canary's state dir. |

* **Header** on the fix: `home=throwaway binary=/var/tmp/xschem_fixes/r2i/ptree/src/xschem`.
* **Arithmetic on the fix:** 87 `Start` / 87 `Finish`, and **`wc -l` = 177** on a green verdict
  (2 sentinels + 86 headers + 86 `Total num fail:` + 3 NOGOLD). With one counted line it is 178; with
  8 it is 185.
* **Display arm:** `PRIVATE Xvfb :10x for this run only`. The sampler saw 12 xschem pids there: the
  11 dcases plus one child. Every other xschem was on `:189`.
* **Per case, DISPLAY unset, fix against base** (`tools/percase.py`): **every shared block is
  identical**.
  * The only counted lines are the four F14 suites, 2 each: `test_op_annot`, `test_ase_optier_0963`,
    `test_unused_attr_0970` and `test_auto_specialize_1201`. Each is `FATAL: signal 11` plus the
    HARNESS line, the same as in the base.
  * The two new blocks, `test_home_isolation` and `_sh`, are at 0.
  * **Check counts** (`tools/checks.py`, the last `RESULT` line of each case log): **84 of the 85
    shared case logs are identical**. The one difference is `test_regression_concurrency_1476`, 37
    against 36: round 1's V4b.
* **Red first (`t1_real`, `XSCHEM_TEST_HOME=real`, DISPLAY `:189`):**
  * clipboard **102 → 220 B**;
  * `clean.spice` and `short.spice` **34 → 148 B**;
  * `geometry` rewritten (4964 → 4796 B);
  * `.xschem/op_annot/` created;
  * 2832 events;
  * `home=real`;
  * its one counted line is the same `open_close` `exit 141`.
* **Coverage the throwaway must not lose** (critic problem 4). Run through the documented
  `run_suites.sh --nogui`, armed, with a **copy** of the fork ngspice in the canary where
  `test_real_home` looks:

  | suite | fork present | no fork |
  |---|---|---|
  | `test_ase_converge_1459` | **76** | 70 |
  | `test_ase_sp_1452` | **61** | 58 |

  * Without the fork, `run_suites.sh` **printed the `skip: EE/fork`, `SE/fork` and `SE3/fork`
    lines under the verdict** (D13.11).
  * Both canaries were byte-identical.

### 2. `run_suites.sh` on the 5 writer suites (M)

The suites: `test_crossview_paste`, `test_signal_short_nohier_0230`, `test_no_untitled_litter`,
`test_schpins_stale_lab_0185` and `test_op_annot`.

| run | cwd | canary | events | left | verdicts |
|---|---|---|---|---|---|
| **`s2_rs_cwdrepo`** | repo | identical | 0 | 0 | 5/5 PASS (op_annot 492) |
| **`s2_rs_cwdcanary`** | **the canary** | **identical, `untitled~.sch` included** | 0 | 0 | 5/5 PASS |
| red first `s2_rs_real` | repo | **CHANGED**: clipboard 102 → 107, clean/short 34 → 148, geometry 4964 → 5211, `.cache/openbox` created | 572 | 0 | 5/5 PASS |
| red first `s2_rs_base_cwdcanary` | the canary, **base** | **CHANGED**: the tester's **`untitled~.sch` overwritten 101 → 219 B**, plus clipboard, clean/short and geometry | 588 | 0 | 5/5 PASS |

D13.11 is visible here: under op_annot's verdict, `run_suites.sh` printed `| skip: W23 … (no action
log -- run with --logdir)`.

### 3. `full_audit.sh`, bounded at 120 min (M)

| run | code | canary | events | left | SUMMARY |
|---|---|---|---|---|---|
| `s3_full_audit` | r2i_1 | identical | 0 | 0 | `391 pass 12 fail 0 crash/timeout 2 skip (total 405)`, 1027 s |
| **`s3_full_audit4`** | **r2i_4** | **identical** | **0** | **0**, its throwaway gone | **`392 pass 11 fail 0 crash/timeout 2 skip (total 405)`**, 831 s |

* **Peak throwaway size:** **68 KB** in both runs (206 and 167 samples, 5 s apart), and there was
  **never more than 1** throwaway at a time.
* **The final run's 11 fails are exactly round 1's pre-existing list** (`S2c-I.md`), and so are
  r2i_1's:
  * `test_altf5_ciw`, `test_ase_dialogs`, `test_cadence_drag`, `test_cosim_golden_e2e`;
  * `test_lib_manager_gui`, `test_lib_sweep`, `test_results_dialog`;
  * `test_rotate_stretch_short_0104`, `test_selflog_output`;
  * `test_wave_sigbrowser_0312`, `test_wave_sigbrowser_keys`.

  **r2i_1 also failed `test_scratch_home_note`.** That is defect B (`S2c-R2-R2I.md`), fixed in
  r2i_3, and it **passes** in the final run, as do `test_home_isolation` and `_sh`.
* The 2 skips are the same as round 1's: `test_expose_repaint` and `test_window_report`.

### 4. `cd tests && tclsh netlisting.tcl` (M)

`s4_netlisting`:
* rc 0, 728 jobs, `No gold folder`;
* canary identical, 0 events;
* banner `test home: throwaway /tmp/xschem-test-home.3463025.IygtPg …`, and that throwaway is gone.

There is no red first here: the in-tree binary is built, and `/usr/local/bin` is empty (as in round 1;
the critic measured F10's red-first with a fake PATH binary).

### 5. The 7 standalone `.sh` suites + `test_devdisplay.sh`, each run as `sh|bash tests/headless/<t>.sh` (M)

| suite | fix: canary / events / left | base (red first) | verdict fix = base |
|---|---|---|---|
| `test_action_log` | identical / 0 / 0 | `.cache/openbox` created (3 events) | ALL PASS, 10 ok |
| `test_action_replay` | identical / 0 / 0 | `.cache/openbox` + `geometry` rewritten (11) | 1 FAILED, same FAIL line (pre-existing) |
| `test_file_menu_log` | identical / 0 / 0 | `.cache/openbox` + `geometry` 4964 → 4965 (9) | 1 FAILED, same FAIL lines (pre-existing) |
| `test_flylines` | identical / 0 / 0 | `.cache/openbox` (4) | ALL PASS, 43 |
| `test_readonly_action_dispatch` | identical / 0 / 0 | `.cache/openbox` + `geometry` 4964 → 4948 (11) | PASS, 4 |
| `test_readonly_guard` | identical / 0 / 0 | `.cache/openbox` (3) | PASS, 13 |
| `test_recent_launchlog` | identical / 0 / 0 | `.cache/openbox` (3) | ALL PASS, 19 |
| `test_devdisplay.sh` | identical / 0 / 0 | `.cache/openbox` + `geometry` 4964 → 4960 (9) | ALL PASS (39) |

* On every row, the number of ok lines and the set of FAIL lines are equal between fix and base.
* The fix's output has exactly one more line: the `test home:` banner.
* `test_devdisplay.sh` used its own `:96` (and `:85`–`:88`, per R2S); `:99` appears 0 times in its
  output.

### 6. `owed.sh drain`, one shell debt and one Tcl debt, in a scratch ledger (M)

* **The ledger:** `r2i/ledgers/s6_owed_<tree>`, holding:
  * `add suite test_readonly_action_dispatch.sh`;
  * `add suite test_crossview_paste` (a clipboard writer).
* **The drain:** `drain --display :183`, my fixture, with the gate live (`GUI_GATE_AUTOSTART=3`).
* **Fix:**
  * both debts PASS and are cleared;
  * two throwaways announced, both gone;
  * **canary identical, 0 events, 0 procs**.
* **Base (red first):**
  * clipboard **102 → 201**;
  * geometry 4964 → 5152;
  * **`.claude/gui_test_gate/` created in the canary** (control, events.log, widget.pid, …), 96 events;
  * **a `wish gui_gate_widget.tcl` panel left running with HOME=canary**. I killed it by identity.

### 7. `run.sh` and `run_nogui.sh` (M)

| run | fix | base |
|---|---|---|
| `sh tests/headless/run_nogui.sh` | identical / 0 / 0, `RESULT: PASS`, banner printed | **CHANGED**: a **1 205 039 B `.xschem/simulations/0_examples_top.spice`** (398 events) |
| `sh tests/headless/run.sh` | identical / 0 / 0, `== HARNESS: PASS ==` | identical: it is already hermetic, so **no red first exists** (as R2S found) |

### 8. ATTACH (M; `s8_attach`, r2i_1)

* **The fixture:** my `Xvfb :186 -audit 4` plus openbox, both with HOME = my scratch. The canary's
  `.claude/xschem_dev_display` names them: `display`, `xvfb.pid`, `wm.pid`, `screen` and `wm`. Run
  with `DEVDISPLAY_NUM=186` and DISPLAY `:189`.
* **Result:** `display arm: attached to the dev display (state dir …/s8_attach/.claude/xschem_dev_display)`
  and **87/86/0**.
* **The dcases really ran there.** The sampler put all **11 dcases** on `:186`, and **every one of
  those pids appears in `:186`'s own audit log** (2 connections each; the simdlg child 1).
* **Canary, state dir included:** byte-identical, 0 events, 0 procs.

### 9. AUTO-START (M; `s9_autostart`, r2i_1)

* **Setup:** the canary has an **empty** `.claude/xschem_dev_display`, its display is down, and
  `DEVDISPLAY_NUM=187`.
* **Result:** `display arm: started the dev display (… with the pre-switch HOME)`, **87/86/0**, and the
  sampler put 11 dcases on `:187`.
* **The started Xvfb `:187` and openbox:**
  * `/proc/<pid>/environ` has **HOME = the canary**;
  * **no `XSCHEM_TEST_*`, no `GIT_CONFIG_*`, no `XSCHEM_DEVDISPLAY_DIR`**;
  * what remains is the tester's own variables (`DEVDISPLAY_NUM`, `XSCHEM_OWED_DIR`, PATH, …).
* **The canary gained only** D13.2's scoped exception:
  * `.claude/xschem_dev_display/{display,screen,wm,wm.pid,xvfb.pid}`, plus that directory's mtime;
  * `.cache/openbox/{openbox.log,sessions/}`.

  18 events, nothing else.
* **Cleanup:** I stopped the display afterwards with `devdisplay.sh stop` against the canary's state
  dir: `stopped :187`, and both pids were gone.

### 10. Concurrency (M)

**Two T1s in one tree, DISPLAY `:189`, launched in the same second. Three pairs:**

| pair | code | A / B trailers | per case | canaries | left |
|---|---|---|---|---|---|
| **`s10_pair3`** | **r2i_4** | **87/86/0 and 87/86/0** | identical | identical, 0 events | 0 |
| `s10_pair2` | r2i_3 | 87/86/0 and 87/86/0 | identical | identical | 0 |
| `s10_pair` | r2i_3 | 87/86/**1** and 87/86/0 | the only difference is A's `open_close` FATAL | identical | 0 |

* **Pair 3 overlapped the solo `t1_final4`**, so three T1s were live. They took `:100`, `:101` and
  `:102`: three distinct numbers.
* **The run that saw a peer said so** (`live_banner=1`).
* **Pair 1's A is not attributable to a job by its detail.** Its `open_close_output.txt` detail was
  overwritten by B's publish, because the canonical file holds the last publisher. It is the same
  shape as the two `exit 141` measured above (I).

**14 concurrent standalone pairs of `test_home_isolation`**, both runs of each pair launched in the
same second, each with its own canary:

| run | code | result | canaries | left |
|---|---|---|---|---|
| **`s10_pairs4`** | **r2i_4** | **28 of 28 `ALL PASS (104 checks)`**, 0 FAIL lines. H1 took `:100` and `:101`, 14 each. | all identical | 0 procs, 0 throwaways |
| `s10_pairs` | r2i_1 | 27 of 28 `ALL PASS (102 checks)` | all identical | 0 |

* **The one red in `s10_pairs`, pair 14b H6** (`{xvfb 1 wm 0 reaper 1}`), was attributed and **fixed
  as defects A and D** (`S2c-R2-R2I.md`).
* The real-arm reproduction after both fixes:
  * 60 driver copies started three at a time;
  * **0 dead WMs**;
  * **0 rounds with a shared display**;
  * 7 lost races, each resolved by moving to the next number.

### 11. `kill -9` (M)

**T1 inside the display arm** (`k9_t1`, r2i_2, DISPLAY unset):
* At the kill it had reached `Start headless/test_op_annot.tcl (display arm)` on `PRIVATE Xvfb :100`,
  with Xvfb, openbox and the reaper all alive.
* After `kill -9` of the T1 tclsh: **Xvfb and openbox gone after 1889 ms**. The reaper had exited and
  the lock was removed.
* 15 s later **no process carried the run's HOME or the canary**, and the canary was identical.
* The run's throwaway was left, as designed. **The next arm swept exactly it:**
  `test home: swept 1 dead run(s)' throwaway home(s) from /tmp (xschem-test-home.4151815.Ltg2Jk)`
  (`sweepdemo`), once its mtime was more than 300 s old.

**`run_suites.sh` after the handoff** (`k9_rs`, r2i_2): the tester's pid P, by then running
`/bin/sh /usr/bin/xvfb-run -n 185 -a …`, was `kill -9`ed.
* **Xvfb and openbox were gone after 1139 ms.**
* The re-exec'd driver Q owned the home (`.owner` = `Q <boot> <ns>`). It carried on without a display
  (`NORESULT` ×5), exited, and its trap deleted the home: **throwaway left: none**.
* No process left, canary identical.

## The crews' own matrices, re-run on the integrated code (M)

* **R2T's 16 sabotages** (`r2i/sabT`, on `sabtree` = r2i_3): **16 of 16 red on their target rows**.
  Several also redden the rows added at integration, which is expected:
  * S2 and S3 → also L13;
  * S4 → also L10b;
  * S14 → also L13.

  S11 additionally showed H6 red with `wm 0`. That was defect D occurring spontaneously; it was
  fixed in r2i_4.
* **R2S's 31 sabotages** (`r2i/sabS`, on `sabtree` = r2i_4):
  * the no-op control stayed **green** (ALL PASS, 82);
  * **all 30 others are RED-AS-EXPECTED**, S01–S32 with no S08 or S20 in their list;
  * every file was md5-restored.

  That covers:
  * D13.1: `--arm`, `--wm-launch-own`, `test_devdisplay.sh`, `run_nogui`, the drain, `--run`, and the
    relocated `owed.sh`;
  * D13.3 (C1 and C2);
  * D13.4 (B1);
  * D13.5 (O5 ×2);
  * D13.6 (F11, G8–G10);
  * D13.7 (G5 and G5b);
  * D13.8 (N8b);
  * D13.9 (X6);
  * D13.11 (S1);
  * D13.15 (X7, X8, and X7 again);
  * D13.16 (K4–K6).
* **`sabtree` was clean in git afterwards**, and so were all six proof trees (0 tracked changes).

## Every counted line in this stage, attributed per case (M)

* **`open_close`, one job `exit 141` (SIGPIPE, issue 0448), 3 times in 15 complete T1 runs**:
  `t1_disp`, `t1_real` and `s10_pairA`. Two were measured through `open_close_output.txt`; the third
  (I) had its detail overwritten.
  * All three ran with at least three heavy runs live.
  * 0448 predates this batch and is "load-dependent".
* **The four F14 suites, 2 lines each, in the two DISPLAY-unset T1s only.** They were identical in
  fix and base (D13.12).
* Nothing else counted.

## Open problems

1. **0448 (SIGPIPE in a parallel `open_close` job) hit 3 of 15 T1 runs here**, all under heavy
   concurrent load. It is not Item 2, but the stage-F gate should run solo, and a red there must be
   attributed by case.
2. **`xvfb-run -a` numbers from `:99`** (R2S open problem 1): `xvfb_arm.sh`'s private path and
   `test_devdisplay.sh` D6. Not changed. When the dev display is down, an armed shell run can briefly
   hold `:99`.
3. **`devdisplay.sh start` has defect D's shape** (R). It probes the server (xdpyinfo) and then starts
   openbox with xprop polls, on an Xvfb without `-noreset`. So the **persistent** dev display can come
   up WM-less, about 3 % by the probe measurement (I, not measured on devdisplay itself).
   **devdisplay's `_ours` also has defect A's shape**: a live pid named `Xvfb :N` plus *any* server
   answering on `:N`. Neither is in this batch's diff; both are recorded.
4. **Pre-existing, from R2S:**
   * `test_devdisplay.sh`'s `_cleanup` removes `/tmp/.X$NUM-lock` by number;
   * `wireedit/run_wireedit.sh` is unarmed when run standalone;
   * a relocated `owed.sh` with no `test_home.sh` beside it runs its debt **unarmed**, with a loud
     warning (the driver's call).
5. **In a concurrent pair, the run whose tcase published first loses its `_output.txt` detail** to
   the other run's publish (seen for pair 1 A). The verdict lines are per run and intact. It is a
   harness observation, pre-existing.
6. **Display numbers outside 180–189, chosen by the code under test:**
   * T1's private arm, `:100`–`:102` (hard-coded from 100);
   * `test_home_isolation`'s fixtures, 150–159;
   * `test_devdisplay.sh`, 85–96.

   Everything I started, and every shim, was in 180–189.
7. **Stage F:** the CLAUDE.md scoping of the done-claim (D13.2) and the D12 issue files, as before.
8. **`/tmp/xschem_emergencysave_*` created during my runs were left in place**, as the rule requires.
   The F14 segfaults of the two DISPLAY-unset T1 runs (I).
9. **Scratch for the driver to delete:** `/var/tmp/xschem_fixes/r2i` (3.8 GB). It holds the trees, base,
   ptree1–5, sabtree, canaries, runs, race, wmrace and tools.

## Real home (M)

* **Marker:** `/var/tmp/xschem_fixes/r2i/.start_marker`, touched 2026-09-18 08:17:06.
* **Manifest:** `md5sum -c --quiet …/xschem_manifest_fixes.md5` gave **rc 0** at the start (08:17),
  mid-stage (09:26) and at the end (11:01).
* **Find:** `find /home/analog/.xschem /home/analog/.claude/xschem_dev_display
  /home/analog/.claude/gui_test_gate /home/analog/.claude/xschem_owed /home/analog/.cache/openbox -newer
  <marker>` printed **nothing**, mid-stage and at the end.
* **No interactive session:** the newest `/tmp/Xschem.log*` is `.4`, from 09-17 23:35.
* **HOME for every run** was a canary or scratch dir under `/var/tmp/xschem_fixes/r2i`.
  * Nothing ran with `HOME=/home/analog`.
  * `XSCHEM_TEST_REAL_HOME` was never set to it. The fork ngspice was **copied** into two canaries.
  * `owed.sh` always ran with `XSCHEM_OWED_DIR` set to a scratch ledger, or to the canary's own
    sentinel ledger.
* **`:99` was never started, probed or stopped.**
  * `DEVDISPLAY_NUM` was 186, 187 or 188 on every run.
  * Every `xvfb-run` was shimmed to `-n 181`…`185`.
  * `test_devdisplay.sh`'s output names `:99` 0 times.
  * `/tmp/.X99-lock` is absent at the end.
* **Displays I started**, all with HOME = my scratch, all stopped by pid:
  * `:189` (T1's DISPLAY), `:186 -audit 4` + openbox (attach), `:183` (drain);
  * `:181`, `:182` and `:184` (the race and reset probes).

  `:187` was started by the code under test in shape 9 and stopped with `devdisplay.sh stop`
  against the canary's state dir.
* **At the end:**
  * no `/tmp/.X*-lock` at all;
  * no `/tmp/xschem-test-home.*`;
  * no `/tmp/xschem-homeiso-fixture.*`;
  * no process whose HOME is under `r2i` or a throwaway;
  * no `xschem-t1-reaper` and no `xvfb_arm.sh --reap`.
* **Emergency-save dirs:** 18 `/tmp/xschem_emergencysave_*` are newer than the marker. They fall at
  08:37–39, 08:50–52 and 09:19–24, which are the times of my DISPLAY-unset T1 runs (F14 segfaults), my
  `test_file_menu_log` runs (`fix`) and the `kill -9` shapes (I). None was named by any output, so
  all were left in place.
* **Other sessions:** the `s1fix3`/`s1fix4` crews ran `test_issue_stamp` in the main tree during this
  stage, with scratch HOMEs (`/var/tmp/xschem_fixes/s1fix4/homes/*`, M: `/proc/<pid>/environ`).
* **Main tree:** only read, plus `git apply --check` (read-only) and `git clone`. Its `git status` is
  the start snapshot plus these two receipts, and HEAD moved only by the driver's own commits.
  `~/dev/xschem-op-wcard` was not touched.
